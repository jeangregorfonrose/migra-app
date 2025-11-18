import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:migra_app/features/home/screens/home_screen.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:provider/provider.dart';


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
        if(user != null) {
          context.read<AppData>().updateUser(user); // safe here
        }
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
