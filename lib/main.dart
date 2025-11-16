import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:migra_app/core/router.dart';
import 'package:migra_app/core/themes/app_theme.dart';
import 'package:migra_app/firebase_options.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:migra_app/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: pass the platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics setup
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(
    ChangeNotifierProvider(create: (_) => AppData(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Immigration Alert App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}

/// Handles auth state and ensures we have an anonymous user before showing the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _signingIn = false;
  String? _error;
  bool _authReady = false; // we got at least one auth event
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();

    // Subscribe to auth changes OUTSIDE build
    _sub = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        context.read<AppData>().updateUser(user!); // safe here
        if (mounted && !_authReady) setState(() => _authReady = true);
      },
      onError: (e) {
        if (mounted && !_authReady) setState(() => _authReady = true);
      },
    );
  }

  Future<void> _ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) {
      // we’ll still wait for the stream event to flip _authReady
      return;
    }
    setState(() {
      _signingIn = true;
      _error = null;
    });

    try {
      await auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_signingIn || !_authReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Sign-in failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _ensureSignedIn,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Auth stream delivered a user (possibly anonymous) → show the app
    return const HomeScreen();
  }
}
