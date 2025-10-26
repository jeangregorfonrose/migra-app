import 'package:migra_app/core/models/location_model.dart';

class Report {
  final String id;
  final String description;
  final DateTime timestamp;
  final Location location;
  final int version;

  Report({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.location,
    required this.version,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['_id'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
      location: Location.fromJson(json['location']),
      version: json['__v'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'location': location.toJson(),
      '__v': version,
    };
  }
}

