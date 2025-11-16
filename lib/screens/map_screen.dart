import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:http/http.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:migra_app/api/api_client.dart';
import 'package:migra_app/api/report_api.dart';
import 'package:migra_app/core/models/location_model.dart';
import 'package:migra_app/core/models/report_model.dart';
import 'package:migra_app/core/themes/app_colors.dart';
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:provider/provider.dart';

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
            AppLogger.map('Updated camera position: ${center.coordinates.lat}, ${center.coordinates.lng}');
          })
          .catchError((e) {
            AppLogger.error('Failed to get camera state', error: e);
          });
    }
  }

  // Confirm placement of report pin
  void _confirmLocationAndOpentSheet() {
    if (_draftCoord == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: No location selected')));
      return;
    }

    AppLogger.map('Report pin placed at: ${_draftCoord!.lat}, ${_draftCoord!.lng}');

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.event_note),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),

                  // Spacing
                  const SizedBox(height: 8),

                  // Location
                  Text(
                    'Location: (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                  // Description of report
                  const Text("Note (optional)"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descriptionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          "Brief details (e.g., uniforms, vehicles, time)",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // Spacing
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      label: const Text('Submit Report'),
                      icon: const Icon(Icons.send),
                      onPressed: () => _submitReport(descriptionCtrl.text),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              );
            },
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

  void _submitReport(String description) {
    // Create a new report
    Report newReport = Report(
      id: '',
      location: Location(
        type: "Point",
        coordinates: [_draftCoord!.lng.toDouble(), _draftCoord!.lat.toDouble()],
      ),
      description: description.isEmpty
          ? ''
          : description,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report submitted'),
              backgroundColor: Colors.green,
            ),
          );
        })
        .catchError((error) {
          AppLogger.error('Error submitting report', error: error);
          // Closing Bottom Sheet
          Navigator.pop(context);

          // Show confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create report'),
              backgroundColor: Colors.red,
            ),
          );
        });
  }

  void _addReportsSource() async {
    if (_map == null) return;

    final style = _map!.style;

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

    // Update the existing source with new data
    try {
      // Create source and add to map style
      await style.addSource(
        mbx.GeoJsonSource(id: "reports_source", data: jsonEncode(collection)),
      );

      final reportsLayer =
          mbx.CircleLayer(id: 'reports_layer', sourceId: 'reports_source')
            ..filter = ["all"]
            ..circleColor =
                0xFFE53935 // Red
            ..circleRadius = 8.0
            ..circleOpacity = 0.9
            ..circleStrokeColor =
                0xFF111111 // Black border
            ..circleStrokeWidth = 1.0;

      await style.addLayer(reportsLayer);

      // Add heatmap layer
      _addHeatmapLayer();
      AppLogger.map('✅ Reports source refreshed with ${_reports.length} reports');
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
          ..heatmapIntensity = 1.0
          // Radius: Size of each heat point in pixels
          ..heatmapRadiusExpression = [
            "interpolate",
            ["linear"],
            ["zoom"],
            0, 10, // Zoomed out: small radius
            10, 50, // Medium zoom: medium radius
          ]
          // Weight: How much each point contributes
          ..heatmapWeight = 0.6
          // Opacity: Fade out as you zoom in
          ..heatmapOpacityExpression = [
            "interpolate",
            ["linear"],
            ["zoom"],
            10, 1.0, // Zoomed out: fully visible
            14, 0.0, // Zoomed in: invisible
          ];
    // Color: Density gradient
    // ..heatmapColorExpression = [
    //   "interpolate",
    //   ["linear"],
    //   ["heatmap-density"],
    //   0.0, "rgb(33,66,235)", // No density: transparent
    //   0.5, "rgb(235,147,33)", // Medium density: yellow
    //   1.0, "rgb(235,33,33)", // High density: red
    // ];

    await style.addLayerAt(heatmapLayer, mbx.LayerPosition(above: "reports_layer"));
  }

  @override
  Widget build(BuildContext context) {
    // Get User Position
    final appData = Provider.of<AppData>(context, listen: false);
    Position userPosition = appData.getUserPosition;
    return Scaffold(
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

          // Fixed pin overlay in center of screen
          if (_isPlacingMarker)
            Center(
              child: Image.asset(
                'assets/icons/pin_marker.png',
                width: 48,
                height: 48,
              ),
            ),

          // Instructions
          if (_isPlacingMarker)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'Move the map to position the pin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // Confirm/Cancel buttons when placing marker
          if (_isPlacingMarker)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'cancel',
                    onPressed: _cancelPlacement,
                    icon: Icon(Icons.close),
                    label: Text('Cancel'),
                    backgroundColor: AppColors.cancelButtonBackground,
                  ),
                  SizedBox(width: 16),
                  FloatingActionButton.extended(
                    heroTag: 'confirm',
                    onPressed: _confirmLocationAndOpentSheet,
                    icon: Icon(Icons.check),
                    label: Text('Confirm'),
                    backgroundColor: AppColors.confirmButtonBackground,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _isPlacingMarker
              ? Container()
              : FloatingActionButton(
                heroTag: 'fab_report',
                onPressed: _startPlacingReportPin,
                child: const Icon(
                  Icons.add_location_alt,
                  color: AppColors.white,
                ),
              ),
          const SizedBox(height: 12),
          _isPlacingMarker
              ? Container()
              : FloatingActionButton(
                heroTag: 'fab_focus',
                onPressed: _focusOnUserLocation,
                child: const Icon(Icons.adjust_rounded, color: AppColors.white),
              ),
        ],
      ),
    );
  }
}
