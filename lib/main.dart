import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
<<<<<<< HEAD
import 'package:migra_app/core/themes/app_theme.dart';
=======
import 'package:migra_app/screens/home_screen.dart';
>>>>>>> iosfixed
import 'screens/login_screen.dart';
import 'screens/report_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immigration Alert App',
<<<<<<< HEAD
      debugShowCheckedModeBanner: true,
      // initialRoute: '/login', // or '/map' if logged in
      // routes: {
      //   '/login': (context) => LoginScreen(),
      //   '/register': (context) => RegisterScreen(),
      //   '/map': (context) => ReportMapScreen(),
      //   '/report': (context) => ReportFormScreen(),
      // },
      theme: AppTheme.lightTheme,
      home: ReportMapScreen(),
=======
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
>>>>>>> iosfixed
    );
  }
}
