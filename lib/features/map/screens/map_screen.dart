import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:migra_app/api/api_client.dart';
import 'package:migra_app/api/report_api.dart';
import 'package:migra_app/core/models/location_model.dart';
import 'package:migra_app/core/models/report_model.dart';
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:migra_app/core/utils/location.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:migra_app/shared/widgets/bouncing_pin.dart';
import 'package:migra_app/shared/widgets/custom_toast.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // API client
  final ReportApi _reportApi = ReportApi(ApiClient(http.Client()));

  // list of reports to display on map
  List<Report> _reports = [];

  // ---------- Map setup ----------
  late String
  accessToken; // access token for the mapbox account, will be set in initState from env

  mbx.MapboxMap? _map;

  // ---------- Report Submission State ----------
  bool _isPlacingMarker = false;
  mbx.Position? _draftCoord; // longitude, latitude
  bool _isStyleLoaded = false; // Track if map style is loaded

  @override
  void initState() {
    super.initState();

    // Get user's actual location
    getUserLocation().then((position) {
      final appData = Provider.of<AppData>(context, listen: false);
      appData.updateUserPosition(position, true);
      AppLogger.map('✅ User location retrieved: ${position.latitude}, ${position.longitude}');
      
      // Center map on user location if map is already created
      if (_map != null) {
        _map!.flyTo(
          mbx.CameraOptions(
            center: mbx.Point(
              coordinates: mbx.Position(
                position.longitude,
                position.latitude,
              ),
            ),
            zoom: 12.0,
          ),
          mbx.MapAnimationOptions(duration: 1000),
        );
      }
    }).catchError((error) {
      AppLogger.error('Error getting user location', error: error);
    });

    // fetch reports from backend
    Future<List<Report>> reportsFuture = _reportApi.fetchReports();

    // set reports when fetched - will be added to map when both reports and style are ready
    reportsFuture
        .then((reports) {
      setState(() {
        _reports = reports;
      });
      AppLogger.map('✅ Fetched ${reports.length} reports from backend');
      // Add reports to map if style is already loaded
      if (_isStyleLoaded && _map != null) {
        _addReportsSource();
      }
    })
        .catchError((error) {
      AppLogger.error('Error fetching reports', error: error);
    });

    // ---------- Mapbox setup ----------
    accessToken = const String.fromEnvironment("ACCESS_TOKEN");
    mbx.MapboxOptions.setAccessToken(accessToken);
  }

  @override
  void dispose() {
    super.dispose();
    _map?.dispose();
  }

  // ---------- Map Report Pin Selection ----------
  Future<void> _startPlacingReportPin() async {
    if (_map == null) return;

    setState(() {
      _isPlacingMarker = true;
    });

    // get current camera center position
    final camera = await _map!.getCameraState();
    final center = camera.center;
    _draftCoord = mbx.Position(center.coordinates.lng, center.coordinates.lat);
  }

  // Update coordinates as map moves
  void _onCameraChange(mbx.CameraChangedEventData data) {
    if (_isPlacingMarker && _map != null) {
      _map!
          .getCameraState()
          .then((camera) {
        final center = camera.center;
        setState(() {
          _draftCoord = mbx.Position(
            center.coordinates.lng,
            center.coordinates.lat,
          );
        });
        AppLogger.map(
          'Updated camera position: ${center.coordinates.lat}, ${center.coordinates.lng}',
        );
      })
          .catchError((e) {
        AppLogger.error('Failed to get camera state', error: e);
      });
    }
  }

  // Confirm placement of report pin
  void _confirmLocationAndOpentSheet() {
    if (_draftCoord == null) {
      CustomToast.show(
          context: context,
          message: 'Error: No location selected',
          type: ToastType.error);
      return;
    }

    AppLogger.map(
      'Report pin placed at: ${_draftCoord!.lat}, ${_draftCoord!.lng}',
    );

    setState(() {
      _isPlacingMarker = false;
    });

    _openSubmitReportSheet(_draftCoord!);
  }

  // Cancel placement of report pin
  void _cancelPlacement() {
    setState(() {
      _isPlacingMarker = false;
      _draftCoord = null;
    });
  }

  // Reverse geocode coordinates to get address
  Future<String> _getAddressFromCoordinates(mbx.Position position) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${position.lng},${position.lat}.json?access_token=$accessToken&language=en',
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          // Get the most relevant address (usually the first one)
          final placeName = features[0]['place_name'] as String;
          return placeName;
        }
      }
    } catch (e) {
      AppLogger.error('Error fetching address', error: e);
    }
    
    // Fallback to coordinates if geocoding fails
    return '(${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})';
  }

  void _openSubmitReportSheet(mbx.Position position) {
    final descriptionCtrl = TextEditingController();
    String locationAddress = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    l10n.submitReport,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Location with address
                  FutureBuilder<String>(
                    future: _getAddressFromCoordinates(position),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.location}: Loading...',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        );
                      }
                      
                      final address = snapshot.data ?? '(${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})';
                      locationAddress = address;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Description
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.whatHappened,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.briefDetails,
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Anonymous Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]?.withOpacity(0.5)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.blue[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 20,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue[300]
                            : Colors.blue[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.anonymousSubmission,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[300]
                                : Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: Text(l10n.submitReport),
                    onPressed: () =>
                        _submitReport(context, descriptionCtrl.text, locationAddress),
                  ),
                ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _focusOnUserLocation() async {
    if (_map == null) return;

    final appData = Provider.of<AppData>(context, listen: false);
    Position userPosition = appData.getUserPosition;

    await _map!.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(
          coordinates: mbx.Position(
            userPosition.longitude,
            userPosition.latitude,
          ),
        ),
        zoom: 12.0,
      ),
      mbx.MapAnimationOptions(duration: 1000),
    );
  }

  void _refreshReports() async {
    final l10n = AppLocalizations.of(context)!;
    
    // Show loading toast
    CustomToast.show(
      context: context, 
      message: l10n.loading, 
      type: ToastType.info
    );
    
    try {
      final reports = await _reportApi.fetchReports();
      setState(() {
        _reports = reports;
      });
      
      if (_isStyleLoaded && _map != null) {
        // Update map source
        final style = _map!.style;
        final reportsSource = await style.getSource('reports_source') as mbx.GeoJsonSource;
        
        final features = _reports.map((r) {
          return {
            "type": "Feature",
            "properties": {
              "id": r.id,
              "description": r.description,
              "timestamp": r.timestamp.toIso8601String(),
            },
            "geometry": r.location.toJson(),
          };
        }).toList();

        final collection = {"type": "FeatureCollection", "features": features};
        await reportsSource.updateGeoJSON(jsonEncode(collection));
        
        AppLogger.map('✅ Reports refreshed: ${reports.length} reports');
        CustomToast.show(
          context: context, 
          message: '${l10n.reports}: ${reports.length}', 
          type: ToastType.success
        );
      }
    } catch (e) {
      AppLogger.error('Error refreshing reports', error: e);
      CustomToast.show(
        context: context, 
        message: l10n.error, 
        type: ToastType.error
      );
    }
  }

  void _submitReport(BuildContext context, String description, String address) {
    // get Translations
    final l10n = AppLocalizations.of(context)!;

    // Create a new report
    Report newReport = Report(
      id: '',
      location: Location(
        type: "Point",
        coordinates: [_draftCoord!.lng.toDouble(), _draftCoord!.lat.toDouble()],
      ),
      description: description.isEmpty ? '' : description,
      address: address.isEmpty ? '' : address,
      timestamp: DateTime.now(),
    );

    // Call the API to submit the report
    _reportApi
        .createReport(newReport)
        .then((report) {
      AppLogger.report('Report submitted: $report');
      _addNewReportToSource(report);

      // Closing Bottom Sheet
      Navigator.pop(context);

      // Show confirmation
      CustomToast.show(
        context: context,
        message: l10n.reportSubmitted,
        type: ToastType.success,
      );
    })
        .catchError((error) {
      AppLogger.error('Error submitting report', error: error);
      // Closing Bottom Sheet
      Navigator.pop(context);

      // Show confirmation
      CustomToast.show(
        context: context,
        message: l10n.failedReportSubmission,
        type: ToastType.error,
      );
    });
  }

  // Handle map tap to show report details
  void _onMapTap(mbx.MapContentGestureContext context) async {
    if (_map == null) return;

    try {
      // Get screen coordinates from touch position
      final screenPoint = context.touchPosition;
      
      // Create a small box around the tap point for better hit detection
      final tapRadius = 10.0;
      
      // Manually encode the screen box as a map
      final boxMap = {
        "min": {
          "x": screenPoint.x - tapRadius,
          "y": screenPoint.y - tapRadius,
        },
        "max": {
          "x": screenPoint.x + tapRadius,
          "y": screenPoint.y + tapRadius,
        },
      };

      // Query rendered features at the tapped point
      final features = await _map!.queryRenderedFeatures(
        mbx.RenderedQueryGeometry(
          value: jsonEncode(boxMap),
          type: mbx.Type.SCREEN_BOX,
        ),
        mbx.RenderedQueryOptions(
          layerIds: ['reports_layer'],
        ),
      );

      if (features.isNotEmpty) {
        // Get the first tapped feature
        final feature = features.first;
        final queriedFeature = feature?.queriedFeature;
        
        if (queriedFeature == null) return;
        
        // Get properties and convert to proper type
        final propertiesRaw = queriedFeature.feature['properties'];
        if (propertiesRaw == null) return;
        
        final properties = Map<String, dynamic>.from(propertiesRaw as Map);
        final reportId = properties['id'] as String;

        // Find the report in our local list
        final report = _reports.firstWhere(
          (r) => r.id == reportId,
          orElse: () => _reports.first,
        );

        // Show report details
        _showReportDetails(report);
      }
    } catch (e) {
      AppLogger.error('Error querying map features', error: e);
    }
  }

  void _showReportDetails(Report report) {
    final l10n = AppLocalizations.of(context)!;

    // Format timestamp
    final timestamp = report.timestamp;
    final formattedDate = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    final formattedTime = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Center(
                    child: Text(
                      l10n.reportDetails,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.date}:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.time}:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.location}:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.address.isEmpty ? '(${report.location.coordinates[1].toStringAsFixed(5)}, ${report.location.coordinates[0].toStringAsFixed(5)})' : report.address,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Description Label
                  Text(
                    l10n.whatHappened,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Description Content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.description.isEmpty
                          ? l10n.noDescription
                          : report.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: report.description.isEmpty
                            ? Colors.grey[500]
                            : null,
                        fontStyle: report.description.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.close),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _addReportsSource() async {
    if (_map == null) return;

    final style = _map!.style;

    // Build updated FeatureCollection with all reports
    final features = _reports.map((r) {
      return {
        "type": "Feature",
        "properties": {
          "id": r.id,
          "description": r.description,
          "timestamp": r.timestamp.toIso8601String(),
        },
        "geometry": r.location.toJson(),
      };
    }).toList();

    final collection = {"type": "FeatureCollection", "features": features};

    // Update the existing source with new data
    try {
      // Create source and add to map style
      await style.addSource(
        mbx.GeoJsonSource(id: "reports_source", data: jsonEncode(collection)),
      );

      // Create a circle layer for report markers
      final reportsLayer = mbx.CircleLayer(
        id: 'reports_layer',
        sourceId: 'reports_source',
      )
        ..circleRadius = 12.0
        ..circleColor = 0xFFE53935 // Red color matching the person pin
        ..circleStrokeWidth = 3.0
        ..circleStrokeColor = 0xFFFFFFFF // White stroke
        ..circleOpacity = 0.9
        ..circleStrokeOpacity = 1.0;

      await style.addLayer(reportsLayer);

      // Add heatmap layer
      _addHeatmapLayer();
      AppLogger.map(
        '✅ Reports source refreshed with ${_reports.length} reports',
      );
    } catch (e) {
      AppLogger.error('❌ Error refreshing source', error: e);
    }
  }

  void _addNewReportToSource(Report report) async {
    if (_map == null) return;

    _reports.add(report); // add to local list

    // Get reports source
    final style = _map!.style;
    final reportsSource =
    await style.getSource('reports_source') as mbx.GeoJsonSource;

    // Build updated FeatureCollection with all reports
    final features =
    _reports.map((r) {
      return {
        "type": "Feature",
        "properties": {
          "id": r.id,
          "description": r.description,
          "timestamp": r.timestamp.toIso8601String(),
        },
        "geometry": r.location.toJson(),
      };
    }).toList();

    final collection = {"type": "FeatureCollection", "features": features};

    await reportsSource.updateGeoJSON(jsonEncode(collection));

    AppLogger.map('✅ New report added to source: ${report.id}');
  }

  void _addHeatmapLayer() async {
    final style = _map!.style;

    // Create heatmap layer using the same 'reports' source
    final heatmapLayer =
    mbx.HeatmapLayer(id: 'reports_heatmap', sourceId: 'reports_source')
      // Show all features
      ..filter = ["all"]
      // Intensity: How strong the heat effect is
      ..heatmapIntensity = 1.2
      // Radius: Size of each heat point in pixels
      ..heatmapRadiusExpression = [
        "interpolate",
        ["linear"],
        ["zoom"],
        0, 2,
        9, 20,
        22, 100,
      ]
      // Weight: How much each point contributes
      ..heatmapWeight = 0.8
      // Opacity: Fade out as you zoom in
      ..heatmapOpacityExpression = [
        "interpolate",
        ["linear"],
        ["zoom"],
        7, 1.0,
        15, 0.2,
      ]
      // Color: Density gradient
      ..heatmapColorExpression = [
        "interpolate",
        ["linear"],
        ["heatmap-density"],
        0,
        "rgba(33, 102, 172, 0)",
        0.2,
        "rgb(103, 169, 207)",
        0.4,
        "rgb(209, 229, 240)",
        0.6,
        "rgb(253, 219, 199)",
        0.8,
        "rgb(239, 138, 98)",
        1,
        "rgb(178, 24, 43)",
      ];

    await style.addLayerAt(
      heatmapLayer,
      mbx.LayerPosition(above: "reports_layer"),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get User Position
    final appData = Provider.of<AppData>(context, listen: false);
    Position userPosition = appData.getUserPosition;

    // Get Translations
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.migraApp),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          mbx.MapWidget(
            styleUri: mbx.MapboxStyles.LIGHT,
            cameraOptions: mbx.CameraOptions(
              center: mbx.Point(
                coordinates: mbx.Position(
                  userPosition.longitude,
                  userPosition.latitude,
                ),
              ),
              zoom: 12.0,
            ),
            onCameraChangeListener: _onCameraChange,
            onTapListener: _onMapTap,
            onStyleLoadedListener: (styleLoadedEventData) async {
              // Mark style as loaded
              _isStyleLoaded = true;
              
              // Enable location puck with 2D default style
              try {
                await _map?.location.updateSettings(
                  mbx.LocationComponentSettings(
                    enabled: true,
                    pulsingEnabled: true, // Pulsing blue circle
                    puckBearingEnabled: true, // Show direction arrow
                  ),
                );
                AppLogger.map('✅ Location puck enabled');
              } catch (e) {
                AppLogger.error('❌ Error enabling location', error: e);
              }
              
              // Add reports source if reports are already fetched
              if (_reports.isNotEmpty) {
                AppLogger.map('✅ Style loaded, adding ${_reports.length} reports to map');
                _addReportsSource();
              } else {
                AppLogger.map('⏳ Style loaded, waiting for reports to be fetched');
              }
            },
            onMapCreated: (mbx.MapboxMap mapboxMap) async {
              _map = mapboxMap;
            },
          ),
          // Bouncing Pin
          if (_isPlacingMarker)
            Center(
              child: BouncingPin(isPlacing: _isPlacingMarker),
            ),

          // Location Selection Panel
          if (_isPlacingMarker)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .scaffoldBackgroundColor
                          .withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.moveMapToPosition,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        if (_draftCoord != null)
                          Text(
                            '${_draftCoord!.lat.toStringAsFixed(5)}, ${_draftCoord!.lng.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton(
                              onPressed: _cancelPlacement,
                              child: Text(
                                l10n.cancel,
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _confirmLocationAndOpentSheet,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(l10n.confirm),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isPlacingMarker
          ? null
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_refresh',
            onPressed: _refreshReports,
            tooltip: l10n.refresh,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'fab_focus',
            onPressed: _focusOnUserLocation,
            tooltip: l10n.focus,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'fab_report',
            onPressed: _startPlacingReportPin,
            tooltip: l10n.createReport,
            child: const Icon(Icons.add_location_alt),
          ),
        ],
      ),
    );
  }
}
