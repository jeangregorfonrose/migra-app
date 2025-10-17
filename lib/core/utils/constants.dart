class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  static const String appName = 'Migra App';
  static const String apiBaseUrl = 'https://migra-backend.onrender.com/';

  // App Bar
  static const String appBarTitle = 'Rapo Imigrasyon';

  // Info Messages
  static const String locationServicesDisabledInfo = 'Location services are disabled. Please enable them in your device settings.';
  static const String locationPermissionDeniedInfo = 'Location permission is denied. Please grant permission in your device settings.';

  // Error messages
  static const String locationServicesDisabled = 'Location services are disabled.';
  static const String locationPermissionDenied = 'Location permissions are denied';
  static const String locationPermissionDeniedForever = 'Location permissions are permanently denied, we cannot request permissions.';
}