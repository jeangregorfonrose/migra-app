import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check authentication first
    await _ensureAuthenticated();
    
    // Then check onboarding status
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      
      // Remove native splash screen before navigating
      FlutterNativeSplash.remove();
      
      if (hasSeenOnboarding) {
        context.go('/map');
      } else {
        context.go('/onboarding');
      }
    }
  }

  Future<void> _ensureAuthenticated() async {
    final auth = FirebaseAuth.instance;
    
    // If already signed in, return
    if (auth.currentUser != null) {
      AppLogger.auth('User already authenticated: ${auth.currentUser!.uid}');
      return;
    }
    
    // Sign in anonymously
    try {
      final userCredential = await auth.signInAnonymously();
      AppLogger.auth('Signed in anonymously: ${userCredential.user!.uid}');
    } catch (e) {
      AppLogger.error('Failed to sign in anonymously', error: e);
      // Show error and retry
      if (mounted) {
        _showErrorDialog();
      }
    }
  }

  void _showErrorDialog() {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.authenticationError),
        content: Text(l10n.authenticationErrorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeApp();
            },
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return a white container or simple loading indicator while initialization completes
    // This will be briefly visible if the native splash screen is removed too early,
    // or if we decide to show a spinner.
    // Since we are removing the native splash screen in _initializeApp, 
    // this widget might not be seen much, but it's good to have a clean background.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
