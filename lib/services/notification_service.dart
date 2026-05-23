import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:io';
import '../main.dart';
import '../screens/note_edit_screen.dart';
import '../screens/task_edit_screen.dart';
import '../models/recurring_interval.dart';
import 'database_service.dart';
import 'alarm_callback.dart';
import 'notification_channels.dart';

const String _notifMetaPrefix = 'notif_meta_';

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
      await ensureReminderChannel(_notificationsPlugin);
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
      // Store notification metadata in SharedPreferences for background isolate
      final prefs = await SharedPreferences.getInstance();
      final meta = {
        'title': title,
        'body': body,
        'payload': payload,
        'scheduledDateMs': scheduledDate.millisecondsSinceEpoch,
        'recurrence': recurrence?.name ?? 'none',
      };

      // Add custom interval info if applicable
      if (recurrence == RecurringInterval.custom) {
        // These will be set from the task data if needed
        // For now they're passed via the payload parsing
      }

      await prefs.setString('$_notifMetaPrefix$id', jsonEncode(meta));

      // Calculate delay from now
      final delay = scheduledDate.difference(DateTime.now());
      if (delay.isNegative && !isRecurring) {
        return false;
      }

      final effectiveDelay = delay.isNegative ? Duration.zero : delay;

      await AndroidAlarmManager.oneShot(
        effectiveDelay,
        id,
        alarmCallback,
        exact: true,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enhanced schedule that includes custom interval data for recurring alarms.
  Future<bool> scheduleNotificationWithCustomInterval({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    RecurringInterval? recurrence,
    int? customIntervalValue,
    CustomIntervalUnit? customIntervalUnit,
  }) async {
    await cancelNotification(id);

    final isRecurring = recurrence != null && recurrence != RecurringInterval.none;
    if (!isRecurring && scheduledDate.isBefore(DateTime.now())) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final meta = {
        'title': title,
        'body': body,
        'payload': payload,
        'scheduledDateMs': scheduledDate.millisecondsSinceEpoch,
        'recurrence': recurrence?.name ?? 'none',
        'customIntervalValue': customIntervalValue,
        'customIntervalUnit': customIntervalUnit?.name,
      };

      await prefs.setString('$_notifMetaPrefix$id', jsonEncode(meta));

      final delay = scheduledDate.difference(DateTime.now());
      if (delay.isNegative && !isRecurring) {
        return false;
      }

      final effectiveDelay = delay.isNegative ? Duration.zero : delay;

      await AndroidAlarmManager.oneShot(
        effectiveDelay,
        id,
        alarmCallback,
        exact: true,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
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
      icon: 'app_icon_2',
      largeIcon: const DrawableResourceAndroidBitmap('app_icon_2'),
      color: const Color(0xFF6366F1),
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails());
    await _notificationsPlugin.show(999, title, fullBody, details);
  }

  Future<void> cancelNotification(int id) async {
    // Cancel the alarm
    await AndroidAlarmManager.cancel(id);
    // Also cancel any shown notification
    await _notificationsPlugin.cancel(id);
    // Clean up stored metadata
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_notifMetaPrefix$id');
  }
}
