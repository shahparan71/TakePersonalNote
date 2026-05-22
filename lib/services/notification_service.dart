import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../main.dart';
import '../screens/note_edit_screen.dart';
import '../screens/task_edit_screen.dart';
import '../models/recurring_interval.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      const channel = MethodChannel('com.take_personal_note/timezone');
      final String? timeZoneName = await channel.invokeMethod<String>('getDeviceTimezone');
      if (timeZoneName != null) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      }
    } catch (e) {
      // Fallback or log error
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final parts = payload.split('_');
          if (parts.length == 2) {
            final type = parts[0];
            final id = int.tryParse(parts[1]);
            if (id != null) {
              if (type == 'note') {
                final note = await DatabaseService().getNoteById(id);
                if (note != null) {
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
                  );
                }
              } else if (type == 'task') {
                final task = await DatabaseService().getTaskById(id);
                if (task != null) {
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)),
                  );
                }
              }
            }
          }
        }
      },
    );

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
  }

  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    RecurringInterval? recurrence,
  }) async {
    await cancelNotification(id);

    final isRecurring = recurrence != null && recurrence != RecurringInterval.none;
    if (!isRecurring && scheduledDate.isBefore(DateTime.now())) {
      return false;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_channel',
            'Reminders',
            channelDescription: 'Task reminders',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            showWhen: true,
            icon: 'ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
            color: const Color(0xFF6366F1),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: recurrence == null || recurrence == RecurringInterval.none || recurrence == RecurringInterval.custom
            ? null
            : recurrence == RecurringInterval.daily
                ? DateTimeComponents.time
                : recurrence == RecurringInterval.weekly
                    ? DateTimeComponents.dayOfWeekAndTime
                    : DateTimeComponents.dayOfMonthAndTime,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> showTestNotification({required String title, required String body}) async {
    final tzName = tz.local.name;
    final fullBody = '$body\nDetected Timezone: $tzName';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Used for testing initial setup',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('ic_notification'),
      color: const Color(0xFF6366F1),
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails());
    await _notificationsPlugin.show(999, title, fullBody, details);
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
