import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:migra_app/core/utils/constants.dart';
import 'package:migra_app/core/utils/location.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:migra_app/screens/chatgpt_report.dart';
import 'package:migra_app/widgets/report_map.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locationEnabled = false;
  bool _locationGranted = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    loadUserLocation();
  }

  void loadUserLocation() async {
    try {
      final position = await getUserLocation();
      setState(() {
        _locationEnabled = true;
        _locationGranted = true;
        _currentPosition = position;
      });

      if(mounted) {
        Provider.of<AppData>(context, listen: false).updateUserPosition(position, false);
      }
    } catch (e) {
      if (e.toString() == AppConstants.locationServicesDisabled) {
        setState(() {
          _locationEnabled = false;
        });
      } else if (e.toString() == AppConstants.locationPermissionDenied ||
          e.toString() == AppConstants.locationPermissionDeniedForever) {
        setState(() {
          _locationGranted = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    // To Review
    if (!_locationEnabled) {
      child = const Text(AppConstants.locationServicesDisabledInfo, textAlign: TextAlign.center);
    } else if (_locationEnabled && !_locationGranted) {
      child = const Text(AppConstants.locationPermissionDeniedInfo, textAlign: TextAlign.center);
    } else if (_locationEnabled && _locationGranted && _currentPosition == null) {
      child = const CircularProgressIndicator();
    } else if (_currentPosition != null) {
      child = const ReportMap();
    } else {
      child = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appBarTitle),
      ),
      body: Center(
        child: child,
      ),
    );
  }
}
