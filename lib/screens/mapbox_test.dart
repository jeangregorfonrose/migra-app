import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxTest extends StatefulWidget {
  @override
  _MapboxTestState createState() => _MapboxTestState();
}

class _MapboxTestState extends State<MapboxTest> {
  late String accessToken;
  late CameraOptions camera;

  @override
  void initState() {
    super.initState();
    accessToken = const String.fromEnvironment("ACCESS_TOKEN");
    MapboxOptions.setAccessToken(accessToken);

    camera = CameraOptions(
      center: Point(coordinates: Position(-98.0, 39.5)),
      zoom: 2,
      bearing: 0,
      pitch: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapo Migrasyon')),
      body: MapWidget(
        cameraOptions: camera,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        label: const Text('Repote'),
        icon: const Icon(Icons.report),
        onPressed: () => print('Report button pressed'),
      ),
    );
  }
}
