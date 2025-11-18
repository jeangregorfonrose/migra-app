import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:migra_app/api/api_client.dart';
import 'package:migra_app/api/report_api.dart';
import 'package:migra_app/core/models/location_model.dart';
import 'package:migra_app/core/models/report_model.dart';
import 'package:migra_app/core/themes/app_colors.dart';
import 'package:migra_app/core/utils/app_logger.dart';
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
  final ReportApi _reportApi = ReportApi(ApiClient(Client()));

  // list of reports to display on map
  List<Report> _reports = [];

  // ---------- Map setup ----------
  late String
  accessToken; // access token for the mapbox account, will be set in initState from env

  mbx.MapboxMap? _map;

  // ---------- Report Submission State ----------
  bool _isPlacingMarker = false;
  mbx.Position? _draftCoord; // longitude, latitude

  @override
  void initState() {
    super.initState();

    // fetch reports from backend
    Future<List<Report>> reportsFuture = _reportApi.fetchReports();

    // set reports when fetched
    reportsFuture
        .then((reports) {
      setState(() {
        _reports = reports;
      });
      _addReportsSource();
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

  void _openSubmitReportSheet(mbx.Position position) {
    final descriptionCtrl = TextEditingController();

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
                  // Location
                  Text(
                    '${l10n.location}: (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
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
                  const SizedBox(height: 20),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: Text(l10n.submitReport),
                      onPressed: () =>
                          _submitReport(context, descriptionCtrl.text),
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

  void _submitReport(BuildContext context, String description) {
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

      final ByteData bytes = await rootBundle.load('assets/icons/person_pin.svg');
      final Uint8List list = bytes.buffer.asUint8List();
      await style.addImage('person-pin', list);

      final reportsLayer = mbx.SymbolLayer(
        id: 'reports_layer',
        sourceId: 'reports_source',
      )
        // ..iconImage = 'police-15' // Default Mapbox icon
        ..iconImage = 'person-pin' // Custom icon
        ..iconSize = 1.5
        ..iconAllowOverlap = true
        ..iconAnchor = mbx.IconAnchor.BOTTOM;

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Migra App"),
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
            onStyleLoadedListener: (styleLoadedEventData) async {
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
          FloatingActionButton.extended(
            heroTag: 'fab_report',
            onPressed: _startPlacingReportPin,
            label: Text(l10n.createReport),
            icon: const Icon(Icons.add_location_alt),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'fab_focus',
            onPressed: _focusOnUserLocation,
            label: Text(l10n.focus),
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
