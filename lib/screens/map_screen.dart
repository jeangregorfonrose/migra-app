import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // ---------- Map setup ----------
  late String accessToken; // access token for the mapbox account, will be set in initState from env
  static const String _styleUri = 'mapbox://styles/YOUR_USERNAME/YOUR_STYLE_ID';
  
  mbx.MapboxMap? _map;

  // ---------- Report Submission State ----------
  bool _isPlacingMarker = false;
  //mbx.PointAnnotationManager? _draftMgr;
  //mbx.PointAnnotation? _draftPin;
  mbx.Position? _draftCoord; // longitude, latitude

  @override
  void initState() {
    super.initState();

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
        print('Updated camera position: ${center.coordinates.lat}, ${center.coordinates.lng}');
      }).catchError((e) {
        print('Failed to get camera state: $e');
      });
    }
  }

  // Confirm placement of report pin
  void _confirmLocation() {
    if(_draftCoord != null) {
      print('Report pin placed at: ${_draftCoord!.lat}, ${_draftCoord!.lng}');
      setState(() {
        _isPlacingMarker = false;
      });
    }
  }

  void _cancelPlacement() {
    setState(() {
      _isPlacingMarker = false;
      _draftCoord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          mbx.MapWidget(
            styleUri: mbx.MapboxStyles.LIGHT,
            onMapCreated: (mbx.MapboxMap mapboxMap) async{
              _map = mapboxMap;

              // Wait for style to load
              await Future.delayed(Duration(milliseconds: 500));

              try{
                // Load custom image as marker
                final ByteData bytes = await rootBundle.load('assets/icons/pin_marker.png');
                final Uint8List imageData = bytes.buffer.asUint8List();
                
                // Use addStyleImage instead of addImage
                await _map?.style.addStyleImage(
                  'pin-marker',
                  1.0, // scale
                  mbx.MbxImage(
                    width: 512, // your image width
                    height: 512, // your image height
                    data: imageData,
                  ),
                  false, // sdf (signed distance field)
                  [], // stretchX
                  [], // stretchY
                  null, // content
                );
                print('✅ Custom marker image loaded');
              } catch (e) {
                print('❌ Error loading marker image: $e');
              }
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
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              bottom: 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'cancel',
                    onPressed: _cancelPlacement,
                    backgroundColor: Colors.grey[700],
                    icon: Icon(Icons.close),
                    label: Text('Cancel'),
                  ),
                  SizedBox(width: 16),
                  FloatingActionButton.extended(
                    heroTag: 'confirm',
                    onPressed: _confirmLocation,
                    backgroundColor: Colors.green,
                    icon: Icon(Icons.check),
                    label: Text('Confirm'),
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
          FloatingActionButton(
            heroTag: 'fab_report',
            onPressed: () => _startPlacingReportPin(),
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.add_location_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_focus',
            onPressed: () => print('Focus button pressed'),
            child: const Icon(Icons.adjust_rounded),
          ),
        ],
      ),
    );
  }
}
