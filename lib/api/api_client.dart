import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:migra_app/core/utils/constants.dart';

class ApiClient {
  static const String baseUrl = AppConstants.apiBaseUrl;
  final http.Client _http;
  final user = FirebaseAuth.instance.currentUser;
  
  // Token caching
  String? _cachedToken;
  DateTime? _tokenExpiry;

  ApiClient(this._http);

  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    
    // First attempt
    var response = await _http.get(uri, headers: await _headers());
    
    // If token expired (401), refresh and retry once
    if (response.statusCode == 401) {
      AppLogger.auth('Token expired, refreshing...');
      await _refreshToken();
      response = await _http.get(uri, headers: await _headers());
    }
    
    return response;
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    
    // First attempt
    var response = await _http.post(uri, headers: await _headers(), body: body);
    
    // If token expired (401), refresh and retry once
    if (response.statusCode == 401) {
      AppLogger.auth('Token expired, refreshing...');
      await _refreshToken();
      response = await _http.post(uri, headers: await _headers(), body: body);
    }
    
    return response;
  }

  Future<void> _refreshToken() async {
    try {
      // Force token refresh
      _cachedToken = await user?.getIdToken(true);
      // Firebase tokens expire in 1 hour, cache for 55 minutes to be safe
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
      AppLogger.auth('Token refreshed successfully');
    } catch (e) {
      AppLogger.error('Error refreshing token', error: e);
      // Clear cache on error
      _cachedToken = null;
      _tokenExpiry = null;
    }
  }

  Future<Map<String, String>> _headers() async {
    String? idToken;
    
    // Use cached token if still valid
    if (_cachedToken != null && 
        _tokenExpiry != null && 
        DateTime.now().isBefore(_tokenExpiry!)) {
      idToken = _cachedToken;
      AppLogger.auth('Using cached token');
    } else {
      // Get fresh token
      try {
        idToken = await user?.getIdToken();
        _cachedToken = idToken;
        // Firebase tokens expire in 1 hour, cache for 55 minutes
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        AppLogger.auth('Fresh token obtained');
      } catch (e) {
        AppLogger.error('Error fetching token', error: e);
      }
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (idToken != null) 'Authorization': 'Bearer $idToken',
    };
  }
}
