import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:http/http.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:migra_app/api/api_client.dart';
import 'package:migra_app/api/report_api.dart';
import 'package:migra_app/core/models/report_model.dart';
import 'package:migra_app/core/themes/app_colors.dart';
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
  // List<Report> _reports = [];
  late Future<List<Report>> _reportsFuture;

  // ---------- Map setup ----------
  late String accessToken; // access token for the mapbox account, will be set in initState from env
  static const String _styleUri = 'mapbox://styles/YOUR_USERNAME/YOUR_STYLE_ID';
  
  mbx.MapboxMap? _map;

  // ---------- Report Submission State ----------
  bool _isPlacingMarker = false;
  mbx.Position? _draftCoord; // longitude, latitude

  @override
  void initState() {
    super.initState();

    // fetch reports from backend
    _reportsFuture = _reportApi.fetchReports();
    _reportsFuture.then((reports) {
      print(reports);
    }).catchError((error) {
      print('Error fetching reports: $error');
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
    if(_map == null) return;

    setState(() {
      _isPlacingMarker = true;
    });

    // get current camera center position
    final camera = await _map!.getCameraState();
    final center = camera.center;
    _draftCoord = mbx.Position(center.coordinates.lng, center.coordinates.lat);
    print('Initial position: ${center.coordinates.lat}, ${center.coordinates.lng}');
  }

  // Update coordinates as map moves
  void _onCameraChange(mbx.CameraChangedEventData data) {
    if(_isPlacingMarker && _map != null) {
        _map!.getCameraState().then((camera) {
        final center = camera.center;
        setState(() {
          _draftCoord = mbx.Position(center.coordinates.lng, center.coordinates.lat);
        });
        // print('Updated camera position: ${center.coordinates.lat}, ${center.coordinates.lng}');
      }).catchError((e) {
        // print('Failed to get camera state: $e');
      });
    }
  }

  // Confirm placement of report pin
  void _confirmLocationAndOpentSheet() {
    if(_draftCoord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No location selected'))
      );
      return;
    }

    print('Report pin placed at: ${_draftCoord!.lat}, ${_draftCoord!.lng}');

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
    String type = 'sighting'; // default type
    double severity = 2;
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
                  // Title
                  const Text(
                    'Submit Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),

                  // Spacing
                  const SizedBox(height: 8),

                  // Location
                  Text(
                    'Location: (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)
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
                      onPressed: () => print('Report submitted!'),
                    )
                  ),
                  
                  const SizedBox(height: 20),
                ],
              );
            }
          )
        );
      },
    );
  }

  void _focusOnUserLocation() async {
    if(_map == null) return;

    final appData = Provider.of<AppData>(context, listen: false);
    Position userPosition = appData.getUserPosition;

    await _map!.setCamera(
      mbx.CameraOptions(
        center: mbx.Point(
          coordinates: mbx.Position(
            userPosition.longitude,
            userPosition.latitude,
          ),
        ),
        zoom: 12.0,
      ),
    );
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
            onMapCreated: (mbx.MapboxMap mapboxMap) async {
              _map = mapboxMap;

              // Wait for style to load
              await Future.delayed(Duration(milliseconds: 500));
            }
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
          _isPlacingMarker ? Container() : FloatingActionButton(
            heroTag: 'fab_report',
            onPressed: _startPlacingReportPin,
            child: const Icon(Icons.add_location_alt, color: AppColors.white,),
          ),
          const SizedBox(height: 12),
          _isPlacingMarker ? Container() :FloatingActionButton(
            heroTag: 'fab_focus',
            onPressed: _focusOnUserLocation,
            child: const Icon(Icons.adjust_rounded, color: AppColors.white,),
          ),
        ],
      ),
    );
  }
}
