import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:migra_app/core/utils/app_logger.dart';

class AppData extends ChangeNotifier {
  //App-wide state variables and methods
  User? user;
  Position? userPosition;
  static const double defaultCenterLat = 40.7128;
  static const double defaultCenterLng = -74.0060; // NYC

  // Setters
  Future<void> updateUser(User newUser) async {
    user = newUser;
    // Get a fresh ID token (JWT)
    // final idToken = await user?.getIdToken(true);
    // print(idToken);
    // print("UUID: ${user!.uid}");
    notifyListeners();
  }

  void updateUserPosition(Position newPosition, bool notify) {
    userPosition = newPosition;
    AppLogger.map('Position Updated: $newPosition');
    if (notify) {
      notifyListeners();
    }
  }

  // Getters
  User? get getUser => user;
  Position get getUserPosition =>
      userPosition ??
      Position(
        longitude: defaultCenterLng,
        latitude: defaultCenterLat,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
  double get getDefaultCenterLat => defaultCenterLat;
  double get getDefaultCenterLng => defaultCenterLng;
}
