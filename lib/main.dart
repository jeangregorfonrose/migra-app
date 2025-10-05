import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:migra_app/core/router.dart';
import 'package:migra_app/core/themes/app_theme.dart';
import 'package:migra_app/firebase_options.dart';
import 'package:migra_app/screens/chatgpt_report.dart';
import 'package:migra_app/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // IMPORTANT: pass the platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
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

    // MaterialApp(
    //   title: 'Immigration Alert App',
    //   debugShowCheckedModeBanner: false,
    //   theme: AppTheme.lightTheme,
    //   home: const ReportMapV2Page(),
    // );

    // MaterialApp.router(
    //   title: 'Immigration Alert App',
    //   debugShowCheckedModeBanner: false,
    //   theme: AppTheme.lightTheme,
    //   routerConfig: appRouter,
    // );
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

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return; // already signed in

    setState(() {
      _signingIn = true;
      _error = null;
    });

    try {
      await auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      // e.code can be 'operation-not-allowed' if Anonymous not enabled
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_signingIn) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Sign-in failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
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

    // At this point, user should exist (anonymous or otherwise).
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          // Rare edge case: not signed in and no error – retry.
          _ensureSignedIn();
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return HomeScreen(user: user);
      },
    );
  }
}
