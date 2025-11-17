import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppData extends ChangeNotifier {
  //App-wide state variables and methods
  // Location related
  User? user;
  Position? userPosition;
  static const double defaultCenterLat = 40.7128; // NYC
  static const double defaultCenterLng = -74.0060;
  
  // Language related
  Locale _locale = const Locale('en');

  AppData() {
    _loadLocale();
  }

  // Helper methods
  bool _isSupported(Locale locale) {
    return ['en', 'es', 'ht'].contains(locale.languageCode);
  }

  void _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  void _saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

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

  void setLocale(Locale locale) {
    if (!_isSupported(locale)) return;
    
    _locale = locale;
    _saveLocale(locale);
    notifyListeners();
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

  Locale get locale => _locale;
}
