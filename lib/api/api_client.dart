import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:migra_app/core/utils/constants.dart';

class ApiClient {
  static const String baseUrl = AppConstants.apiBaseUrl;
  final http.Client _http;
  final user = FirebaseAuth.instance.currentUser;

  ApiClient(this._http);

  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return await _http.get(uri, headers: await _headers());
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    return await _http.post(uri, headers: await _headers(), body: body);
  }

  Future<Map<String, String>> _headers() async {
    String? idToken;
    // get auth token if user is logged in
    try {
       idToken = await user?.getIdToken();
      AppLogger.auth('Fresh token: $idToken');
    } catch (e) {
      AppLogger.error('Error fetching token: $e');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (idToken != null) 'Authorization': 'Bearer $idToken',
    };
  }
}
