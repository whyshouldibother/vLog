import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/reminder.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));
    _initialized = true;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.enabled) return;
    await _cancel(reminder.id);

    if (reminder.dueDate != null) {
      await _scheduleAt(
        id: _hashId(reminder.id),
        title: reminder.title,
        body: reminder.description.isNotEmpty
            ? reminder.description
            : 'Reminder due',
        scheduledDate: tz.TZDateTime.from(reminder.dueDate!, tz.local),
        payload: reminder.id,
      );
    }
    // Distance-based reminders are checked in-app (no system notification for odometer)
  }

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminders',
      'Maintenance Reminders',
      channelDescription: 'Vehicle maintenance due notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> _cancel(String reminderId) async {
    await _plugin.cancel(_hashId(reminderId));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  int _hashId(String s) => s.hashCode & 0x7fffffff;
}