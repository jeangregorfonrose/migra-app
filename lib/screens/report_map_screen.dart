import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class ReportMapScreen extends StatefulWidget {
  @override
  _ReportMapScreenState createState() => _ReportMapScreenState();
}

class _ReportMapScreenState extends State<ReportMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng _initialPosition = LatLng(
    18.488829386620246,
    -69.89349417670161
  ); // Default to SF

  @override
  void initState() {
    super.initState();
    //_fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      // final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      // final response = await http.get(
      //   Uri.parse('https://your-backend.onrender.com/reports'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );

      // if (response.statusCode == 200) {
      //   final List data = jsonDecode(response.body);
      //   setState(() {
      //     _markers = data.map((report) {
      //       return Marker(
      //         markerId: MarkerId(report['_id']),
      //         position: LatLng(report['lat'], report['lng']),
      //         infoWindow: InfoWindow(title: report['description']),
      //       );
      //     }).toSet();
      //   });
      // } else {
      //   print('Failed to load reports');
      // }
    } catch (e) {
      print('Error fetching reports: $e');
    }
  }

  void _goToReportScreen() {
    Navigator.pushNamed(context, '/report'); // Add route in main.dart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapo Migrasyon')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 12),
        onMapCreated: (controller) => _mapController = controller,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: _goToReportScreen,
        label: const Text('Repote'),
        icon: const Icon(Icons.report),
      ),
    );
  }
}
