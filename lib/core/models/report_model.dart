import 'package:migra_app/core/models/location_model.dart';

class Report {
  final String id;
  final String description;
  final String address;
  final DateTime timestamp;
  final Location location;
  int version;

  Report({
    required this.id,
    required this.description,
    required this.address,
    required this.timestamp,
    required this.location,
    this.version = 0,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['_id'],
      description: json['description'],
      address: json['address'],
      timestamp: DateTime.parse(json['timestamp']),
      location: Location.fromJson(json['location']),
      version: json['__v'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'address': address,
      'timestamp': timestamp.toIso8601String(),
      'location': location.toJson(),
    };
  }
}

