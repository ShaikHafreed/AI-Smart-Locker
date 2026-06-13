import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {

  static final FlutterLocalNotificationsPlugin
      notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {

    const AndroidInitializationSettings
        androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const InitializationSettings
        settings =
        InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(
      settings,
    );
  }

  static Future<void>
      showNotification(
    String title,
    String body,
  ) async {

    const AndroidNotificationDetails
        androidDetails =
        AndroidNotificationDetails(
      'locker_channel',
      'Smart Locker',
      importance:
          Importance.max,
      priority:
          Priority.high,
    );

    const NotificationDetails
        details =
        NotificationDetails(
      android: androidDetails,
    );

    await notifications.show(
      0,
      title,
      body,
      details,
    );
  }
}