import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';
import 'notification_service.dart';

import 'screens/dashboard_screen.dart';

Future<void> _firebaseBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await NotificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(
    _firebaseBackgroundHandler,
  );

  NotificationSettings settings =
      await FirebaseMessaging.instance
          .requestPermission();

  print(
    "Permission Status: ${settings.authorizationStatus}",
  );

  String? token =
      await FirebaseMessaging.instance
          .getToken();

  print(
    "FCM TOKEN => $token",
  );

  if (token != null) {
    await ApiService.registerToken(
      token,
    );
  }

  FirebaseMessaging.onMessage.listen(
    (RemoteMessage message) {

      NotificationService.showNotification(
        message.notification?.title ??
            "Smart Locker",
        message.notification?.body ??
            "",
      );
    },
  );

  runApp(
    const SmartLockerApp(),
  );
}

class SmartLockerApp
    extends StatelessWidget {

  const SmartLockerApp({
    super.key,
  });

  @override
  Widget build(
      BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner:
          false,

      title: "AI Smart Locker",

      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),

      home:
          const DashboardScreen(),
    );
  }
}