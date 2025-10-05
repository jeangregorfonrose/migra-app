import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:provider/provider.dart';

class ReportMap extends StatefulWidget {
  const ReportMap({super.key});

  @override
  State<ReportMap> createState() => _ReportMapState();
}

class _ReportMapState extends State<ReportMap> {
  @override
  Widget build(BuildContext context) {
    // Get the user position from AppData, returns default if user position is null
    Position userPosition = Provider.of<AppData>(context, listen: false).getUserPosition;
    
    return Container(
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: Text('User Position: Lat ${userPosition.latitude}, Lng ${userPosition.longitude}'),
            ),
          ],
        ),
      )
    );
  }
}