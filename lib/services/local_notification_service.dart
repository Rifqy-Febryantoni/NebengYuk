import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles Android system tray notifications.
/// These appear in the notification bar even when the app is minimized.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static int _notifId = 0;

  /// Initialize the notification plugin. Call once in main().
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Create the notification channel for Android 8+
    const channel = AndroidNotificationChannel(
      'nebengyuk_channel',
      'NebengYuk Notifications',
      description: 'Notifications for ride updates, bookings, and driver alerts',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Show a system tray notification on Android.
  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'nebengyuk_channel',
      'NebengYuk Notifications',
      channelDescription: 'Notifications for ride updates, bookings, and driver alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _notifId++,
      title,
      body,
      details,
    );
  }
}
