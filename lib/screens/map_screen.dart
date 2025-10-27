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
  mbx.PointAnnotationManager? _draftMgr;
  mbx.PointAnnotation? _draftPin;
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

    // get current camera center position
    final camera = await _map!.getCameraState();
    final center = camera.center;
    print('Center position: ${center.coordinates.lat}, ${center.coordinates.lng}');

    _draftCoord = mbx.Position(center.coordinates.lng, center.coordinates.lat);

    // Create draft annotation manager ONCE if not aleady created
    if(_draftMgr == null) {
      _draftMgr = await _map!.annotations.createPointAnnotationManager();

      // setup drag events
      _draftMgr!.dragEvents(
        onEnd: (annotation) {
          // Called when drag ends
          final geom = annotation.geometry;
          _draftCoord = geom.coordinates;
          print('Draft pin moved to: ${_draftCoord!.lat}, ${_draftCoord!.lng}');
        },
      );
    }

    // if Pin already exists, just update position
    if(_draftPin != null) {
      _draftPin!.geometry = mbx.Point(coordinates: _draftCoord!);
      await _draftMgr!.update(_draftPin!);
      print('📍 Updated existing pin position');
    } else {
      // Create new draft pin
      final pinOptions = mbx.PointAnnotationOptions(
        geometry: mbx.Point(coordinates: _draftCoord!),
        iconImage: 'pin-marker',
        iconSize: 0.07,
        isDraggable: true,
      );

      _draftPin = await _draftMgr!.create(pinOptions);

      print('✅ Created new draft pin');
    }

    setState(() {
      _isPlacingMarker = true;
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
                    width: 64, // your image width
                    height: 64, // your image height
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
