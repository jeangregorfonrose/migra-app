import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:migra_app/core/themes/app_colors.dart';
import 'package:migra_app/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 5000));
    
    // Check authentication first
    await _ensureAuthenticated();
    
    // Then check onboarding status
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      
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
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.location_on,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // App name
            const Text(
              'Migra',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 40),
            
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
