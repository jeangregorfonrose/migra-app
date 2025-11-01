import 'dart:convert';

import 'package:migra_app/api/api_client.dart';
import 'package:migra_app/core/models/report_model.dart';

class ReportApi {
  final ApiClient _client;

  ReportApi(this._client);

  // Add code to fetch reports from backend
  Future<List<Report>> fetchReports() async {
    final response = await _client.get('/reports');

    // Parse response and return list of Report objects
    if (response.statusCode == 200) {
      // Assuming response body is a JSON array of reports
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Report.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load reports');
    }
  }

  // Add code to create a new report
  Future<Report> createReport(Report report) async {
    final response = await _client.post(
      '/report',
      body: jsonEncode(report.toJson()),
    );

    if (response.statusCode == 201) {
      final responseJson = jsonDecode(response.body);
      final reportJson = responseJson['data'];
      return Report.fromJson(reportJson);
    } else {
      throw Exception('Failed to create report');
    }
  }
}