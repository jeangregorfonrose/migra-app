import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math; // for Random + screen point
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:migra_app/providers/app_data.dart';
import 'package:provider/provider.dart';

/// Simple report model
class Report {
  final String id;
  final double lat;
  final double lng;
  final String type;   // "checkpoint" | "sighting" | "raid"
  final int severity;  // 1..3
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.severity,
    required this.createdAt,
  });
}

class ReportMapV2Page extends StatefulWidget {
  const ReportMapV2Page({super.key});

  @override
  State<ReportMapV2Page> createState() => _ReportMapV2PageState();
}

class _ReportMapV2PageState extends State<ReportMapV2Page>
    with SingleTickerProviderStateMixin {
  // ---------- Map setup ----------
  late String accessToken;
  static const _initialCenterLat = 40.7128;
  static const _initialCenterLng = -74.0060; // NYC
  static const String _styleUri = 'mapbox://styles/YOUR_USERNAME/YOUR_STYLE_ID';

  mbx.MapboxMap? _map;

  // ---------- Pulse overlay ----------
  late final AnimationController _pulseCtl;
  late final Animation<double> _pulse;
  math.Point<double>? _pulseScreenPx; // screen location of the highlight point

  // Highlighted report for the pulsing overlay
  final Report _highlight = Report(
    id: 'r_highlight',
    lat: 40.71455,
    lng: -74.00712,
    type: 'sighting',
    severity: 2,
    createdAt: DateTime.now(),
  );

  // Demo data for clustering
  late final List<Report> _reports = List.generate(50, (i) {
    final rnd = math.Random(i);
    final lat = 40.71 + (rnd.nextDouble() - 0.5) * 0.06;
    final lng = -74.01 + (rnd.nextDouble() - 0.5) * 0.06;
    return Report(
      id: 'r$i',
      lat: lat,
      lng: lng,
      type: (i % 3 == 0) ? 'raid' : ((i % 3 == 1) ? 'sighting' : 'checkpoint'),
      severity: (i % 3) + 1,
      createdAt: DateTime.now().subtract(Duration(minutes: i * 5)),
    );
  });

  @override
  void initState() {
    super.initState();
    accessToken = const String.fromEnvironment("ACCESS_TOKEN");
    mbx.MapboxOptions.setAccessToken(accessToken);
    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulse = CurvedAnimation(parent: _pulseCtl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    super.dispose();
  }

  // ---------- Map lifecycle ----------

  Future<void> _onStyleLoaded() async {
    await _addReportsSource();
    await _addUnclusteredLayersByType(); // 3 layers: raid / checkpoint / sighting
    await _addClusterLayer();            // single-color circles for clusters
    await _updatePulseScreenPos();       // initial pulse position
  }

  Future<void> _updatePulseScreenPos() async {
    if (!mounted || _map == null) return;
    try {
      final screen = await _map!.pixelForCoordinate(
        mbx.Point(coordinates: mbx.Position(_highlight.lng, _highlight.lat)),
      );
      setState(() {
        _pulseScreenPx = math.Point<double>(screen.x, screen.y);
      });
    } catch (_) {
      // ignore while camera is animating or off-screen
    }
  }

  Future<void> _flyToHighlight() async {
    if (_map == null) return;
    await _map!.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(
          coordinates: mbx.Position(_highlight.lng, _highlight.lat),
        ),
        zoom: 14.5,
      ),
      mbx.MapAnimationOptions(duration: 1000),
    );
    await _updatePulseScreenPos();
  }

  // ---------- Sources & layers ----------
  
  Future<void> _addReportsSource() async {
    final style = await _map!.style;

    // Build one FeatureCollection containing all reports + the highlight
    final features = _reports.map((r) {
      return {
        "type": "Feature",
        "properties": {
          "id": r.id,
          "type": r.type,
          "severity": r.severity,
        },
        "geometry": {
          "type": "Point",
          "coordinates": [r.lng, r.lat]
        }
      };
    }).toList();

    features.add({
      "type": "Feature",
      "properties": {
        "id": _highlight.id,
        "type": _highlight.type,
        "severity": _highlight.severity,
        "highlight": true,
      },
      "geometry": {
        "type": "Point",
        "coordinates": [_highlight.lng, _highlight.lat]
      }
    });

    final collection = {
      "type": "FeatureCollection",
      "features": features,
    };

    final source = mbx.GeoJsonSource(
      id: 'reports',
      data: jsonEncode(collection),
      cluster: true,
      clusterRadius: 60,
      clusterMaxZoom: 14,
    );

    await style.addSource(source);
  }

  /// Create three unclustered layers with constant colors and simple filters.
  /// We avoid Expression DSL and use raw filter arrays.
  Future<void> _addUnclusteredLayersByType() async {
    final style = await _map!.style;

    Future<void> addTypeLayer({
      required String id,
      required String typeValue,
      required int colorHex,
      double radius = 8.0,
    }) async {
      final layer = mbx.CircleLayer(id: id, sourceId: 'reports')
        // Only show non-clustered points of this 'type'
        ..filter = [
          "all",
          ["!", ["has", "point_count"]],
          ["==", ["get", "type"], typeValue],
        ]
        ..circleColor = colorHex
        ..circleRadius = radius
        ..circleOpacity = 0.9
        ..circleStrokeColor = 0xFF111111
        ..circleStrokeWidth = 1.0;

      await style.addLayer(layer);
    }

    await addTypeLayer(
      id: 'reports-raid',
      typeValue: 'raid',
      colorHex: 0xFFE53935, // red
    );

    await addTypeLayer(
      id: 'reports-checkpoint',
      typeValue: 'checkpoint',
      colorHex: 0xFF00ACC1, // teal
    );

    await addTypeLayer(
      id: 'reports-sighting',
      typeValue: 'sighting',
      colorHex: 0xFFFDD835, // amber
    );

    // Optional: make the single highlighted feature a bit bigger (same color as its type)
    final highlight = mbx.CircleLayer(id: 'reports-highlight', sourceId: 'reports')
      ..filter = [
        "all",
        ["!", ["has", "point_count"]],
        ["==", ["get", "highlight"], true],
      ]
      ..circleColor = 0xFFFDD835 // match its 'sighting' color here
      ..circleRadius = 10.0
      ..circleOpacity = 0.95
      ..circleStrokeColor = 0xFF111111
      ..circleStrokeWidth = 1.0;

    await style.addLayer(highlight);
  }

  /// Single cluster circle layer (fixed color). We skip the count labels to avoid expression needs.
  Future<void> _addClusterLayer() async {
    final style = await _map!.style;

    final clusterLayer = mbx.CircleLayer(
      id: 'reports-clusters',
      sourceId: 'reports',
    )
      ..filter = ["has", "point_count"]
      ..circleColor = 0xFF3949AB // indigo
      ..circleRadius = 18.0
      ..circleOpacity = 0.85;

    await style.addLayer(clusterLayer);

    // If you want cluster count labels, you'd typically add a SymbolLayer and set
    // textField to ["get","point_count_abbreviated"], which needs expressions.
    // The current SDK lacks Expression DSL helpers; raw arrays may not be accepted
    // for textField, so we omit it for compatibility.
  }

  void _openSubmitReportSheet() async {
  String type = 'sighting'; // default
  double severity = 2;       // 1..3
  final noteCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Submit report",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),

                const Text("Type"),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'sighting',   child: Text('Sighting')),
                    DropdownMenuItem(value: 'checkpoint', child: Text('Checkpoint')),
                    DropdownMenuItem(value: 'raid',       child: Text('Raid')),
                  ],
                  onChanged: (v) => setModalState(() => type = v ?? 'sighting'),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("Severity"),
                    Expanded(
                      child: Slider(
                        value: severity,
                        min: 1, max: 3, divisions: 2,
                        label: severity.round().toString(),
                        onChanged: (v) => setModalState(() => severity = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text("Note (optional)"),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Brief details (e.g., uniforms, vehicles, time)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text("Submit"),
                    onPressed: () async {
                      // // Get camera center as report location
                      // final center = await _getCameraLatLng();
                      // if (center == null) {
                      //   if (!mounted) return;
                      //   Navigator.pop(ctx);
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     const SnackBar(content: Text('Map not ready yet')),
                      //   );
                      //   return;
                      // }

                      // final id = DateTime.now().millisecondsSinceEpoch.toString();
                      // final r = Report(
                      //   id: id,
                      //   lat: center.dy,
                      //   lng: center.dx,
                      //   type: type,
                      //   severity: severity.round(),
                      //   createdAt: DateTime.now(),
                      //   note: noteCtrl.text.isEmpty ? null : noteCtrl.text.trim(),
                      // );

                      // // Update local list
                      // setState(() {
                      //   _reports.insert(0, r);
                      //   // Optionally add pulses for certain types:
                      //   // if (r.type == 'raid') _pulsedReports.add(r);
                      // });

                      // await _refreshReportsSource();
                      // if (!mounted) return;
                      // Navigator.pop(ctx);

                      // // Optional: animate camera slightly + toast
                      // await _map!.flyTo(
                      //   mbx.CameraOptions(
                      //     center: mbx.Point(
                      //       coordinates: mbx.Position(r.lng, r.lat),
                      //     ),
                      //     zoom: 14.5,
                      //   ),
                      //   mbx.MapAnimationOptions(duration: 800),
                      // );
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   const SnackBar(content: Text('Report submitted')),
                      // );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    Position? userPosition = appData.getUserPosition;
    return Scaffold(
      body: Stack(
        children: [
          mbx.MapWidget(
            key: const ValueKey('mapbox-map'),
            styleUri: mbx.MapboxStyles.MAPBOX_STREETS, // <- built-in style
            cameraOptions: mbx.CameraOptions(
              center: mbx.Point(
                coordinates: mbx.Position(userPosition?.longitude as num, userPosition?.latitude as num),
              ),
              zoom: 12.5,
            ),

            // 1) Get MapboxMap instance
            onMapCreated: (mapboxMap) {
              _map = mapboxMap;
            },

            // 2) Style is ready -> add sources/layers
            onStyleLoadedListener: (event) async {
              await _onStyleLoaded();
            },

            // 3) Keep pulse pinned while the camera moves
            onCameraChangeListener: (event) {
              _updatePulseScreenPos();
            },

            // (Optional) After first frame fully rendered
            onMapLoadedListener: (_) {},
          ),

          // Pulsing overlay (Flutter-driven) at the highlight's screen point
          if (_pulseScreenPx != null)
      // 👇 Positioned is now a direct child of Stack
      Positioned(
        left: _pulseScreenPx!.x,   // anchor at the screen point
        top:  _pulseScreenPx!.y,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;               // 0..1
              final radius  = lerpDouble(8, 36, t)!;
              final opacity = (1.0 - t).clamp(0.0, 1.0);

              // shift by -radius so the circle stays centered on the anchor
              return Transform.translate(
                offset: Offset(-radius, -radius),
                child: Container(
                  width:  radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.15 * opacity),
                    border: Border.all(
                      width: 2,
                      color: Colors.red.withOpacity(0.5 * opacity),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        spreadRadius: 2,
                        color: Colors.red.withOpacity(0.25 * opacity),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_report',
            onPressed: _openSubmitReportSheet,
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Report here'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_focus',
            onPressed: _flyToHighlight,
            icon: const Icon(Icons.place),
            label: const Text('Focus'),
          ),
        ],
      ),
    );
  }
}
