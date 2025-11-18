// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:migra_app/features/auth/screens/auth_gate.dart';
import 'package:migra_app/screens/chatgpt_report.dart';
import 'package:migra_app/features/settings/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) => const MaterialPage(child: AuthGate()),
    ),
    GoRoute(
      path: '/map',
      name: 'map',
      pageBuilder: (ctx, state) => const MaterialPage(child: ReportMapV2Page()),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (ctx, state) => const MaterialPage(child: SettingsScreen()),
    ),
    // GoRoute(
    //   path: '/pick-location',
    //   name: 'pickLocation',
    //   pageBuilder: (ctx, state) {
    //     // Accept optional query params for initial lat/lng
    //     final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ?? 40.7128;
    //     final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '') ?? -74.0060;
    //     final styleUri = state.uri.queryParameters['style'];
    //     return MaterialPage(
    //       child: LocationPickerPage(
    //         initialLat: lat,
    //         initialLng: lng,
    //         styleUri: styleUri,
    //       ),
    //     );
    //   },
    // ),
    // GoRoute(
    //   path: '/report/:id',
    //   name: 'reportDetails',
    //   pageBuilder: (ctx, state) {
    //     final id = state.pathParameters['id']!;
    //     return MaterialPage(child: ReportDetailsPage(reportId: id));
    //   },
    // ),
  ],
);
