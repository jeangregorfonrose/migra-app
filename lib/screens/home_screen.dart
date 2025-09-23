import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Immigration Watch'),
        actions: [
          IconButton(
            tooltip: 'UID',
            icon: const Icon(Icons.fingerprint),
            onPressed: () {
              final uid = user.uid;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('UID: $uid')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Signed in anonymously ✅\nUID:\n${user.uid}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
