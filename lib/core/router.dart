import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:migra_app/features/map/screens/map_screen.dart';
import 'package:migra_app/features/splash/screens/splash_screen.dart';
import 'package:migra_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:migra_app/features/settings/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      pageBuilder: (context, state) => const MaterialPage(child: SplashScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (context, state) => const MaterialPage(child: OnboardingScreen()),
    ),
    GoRoute(
      path: '/map',
      name: 'map',
      pageBuilder: (ctx, state) => const MaterialPage(child: MapScreen()),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (ctx, state) => const MaterialPage(child: SettingsScreen()),
    ),
  ],
);
