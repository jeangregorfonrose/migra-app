import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

    // ---------- Mapbox setup ----------
    accessToken = const String.fromEnvironment("ACCESS_TOKEN");
    mbx.MapboxOptions.setAccessToken(accessToken);

    // ---------- Animation setup ----------
  }

  @override
  void dispose() {
    // _pulseCtl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          mbx.MapWidget(
            styleUri: mbx.MapboxStyles.LIGHT,
            onMapCreated: (mbx.MapboxMap mapboxMap) {
              _map = mapboxMap;
            },
          ),
        ],
      ),
    );
  }
}
