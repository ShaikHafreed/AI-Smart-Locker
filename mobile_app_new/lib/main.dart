import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission();

  print(
    "Permission Status: ${settings.authorizationStatus}",
  );

  String? token =
      await FirebaseMessaging.instance.getToken();

  print(
    "FCM TOKEN: $token",
  );

  runApp(
    const SmartLockerApp(),
  );
}

class SmartLockerApp extends StatelessWidget {
  const SmartLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AI Smart Locker",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DashboardScreen(),
    );
  }
}