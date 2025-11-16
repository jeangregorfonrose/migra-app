import 'package:logger/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  // Debug - only in development
  static void debug(String message, [dynamic data]) {
    _logger.d(message);
    if (data != null) _logger.d(data);
  }

  // Info - important events
  static void info(String message) {
    _logger.i(message);
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.log('INFO: $message');
    }
  }

  // Warning - potential issues
  static void warning(String message) {
    _logger.w(message);
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.log('WARNING: $message');
    }
  }

  // Error - with crash reporting
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: message,
        fatal: fatal,
      );
    }
  }

  // Feature-specific loggers
  static void network(String message, {dynamic data}) {
    debug('🌐 [NETWORK] $message', data);
  }

  static void database(String message, {dynamic data}) {
    debug('💾 [DATABASE] $message', data);
  }

  static void auth(String message) {
    info('🔐 [AUTH] $message');
  }

  static void location(String message) {
    debug('📍 [LOCATION] $message');
  }

  static void map(String message) {
    debug('🗺️  [MAP] $message');
  }

  static void report(String message) {
    info('📋 [REPORT] $message');
  }

  // Set user context for crash reports
  static void setUserContext(String userId, {String? email}) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
      if (email != null) {
        FirebaseCrashlytics.instance.setCustomKey('user_email', email);
      }
    }
  }

  // Clear user context (on logout)
  static void clearUserContext() {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.setUserIdentifier('');
    }
  }
}