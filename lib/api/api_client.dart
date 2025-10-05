import 'package:http/http.dart' as http;
import 'package:migra_app/core/utils/constants.dart';

class ApiClient {
  static const String baseUrl = AppConstants.apiBaseUrl;

  final http.Client _http;

  ApiClient(this._http);

  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return await _http.get(uri, headers: _headers());
  }

  Future<http.Response> post (String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    return await _http.post(uri, headers: _headers(), body: body);
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    // add Auth token if needed
    };
  }
}