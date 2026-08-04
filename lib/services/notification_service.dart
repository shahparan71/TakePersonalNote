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
import '../models/task.dart';
import '../utils/date_utils.dart';
import 'database_service.dart';
import 'notification_channels.dart';

List<AndroidScheduleMode> getReminderScheduleModeCandidates({required bool canUseExactAlarms}) {
  if (canUseExactAlarms) {
    return [
      AndroidScheduleMode.exact,
      AndroidScheduleMode.inexact,
    ];
  }

  return [
    AndroidScheduleMode.inexact,
  ];
}

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
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
  }

  Future<bool> hasExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return (await androidImplementation?.canScheduleExactNotifications()) ?? false;
    }
    return true; // Not required on iOS or other platforms
  }

  Future<void> requestExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Could not request exact alarms permission: $e');
      }
    }
  }

  /// Re-schedules all pending reminders from the database (e.g. after reboot).
  Future<void> rescheduleAllReminders() async {
    final db = DatabaseService();
    final tasks = await db.getAllTasks();
    for (final task in tasks) {
      if (task.id == null || task.reminderTime == null) continue;
      if (task.status == NoteTaskStatus.completed) continue;
      final title = task.title.isNotEmpty ? task.title : 'Task Reminder';
      await scheduleNotificationWithCustomInterval(
        id: task.id! + 10000,
        title: 'Task Reminder',
        body: title,
        scheduledDate: task.reminderTime!,
        payload: 'task_${task.id}',
        recurrence: task.isRecurring ? task.recurringInterval : RecurringInterval.none,
        customIntervalValue: task.customIntervalValue,
        customIntervalUnit: task.customIntervalUnit,
      );
    }

    final notes = await db.getAllNotes();
    for (final note in notes) {
      if (note.id == null || note.reminderTime == null) continue;
      await scheduleNotification(
        id: note.id!,
        title: 'Note Reminder',
        body: note.title.isNotEmpty ? note.title : 'Untitled',
        scheduledDate: note.reminderTime!,
        payload: 'note_${note.id}',
        recurrence: note.isRecurring ? note.recurringInterval : RecurringInterval.none,
      );
    }
  }

  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    RecurringInterval? recurrence,
  }) {
    return scheduleNotificationWithCustomInterval(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      recurrence: recurrence,
    );
  }

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

    final effectiveDate = _effectiveScheduleDate(
      scheduledDate,
      recurrence,
      customIntervalValue: customIntervalValue,
      customIntervalUnit: customIntervalUnit,
    );

    if (!isRecurring && effectiveDate.isBefore(DateTime.now())) {
      return false;
    }

    Object? lastError;
    for (final mode in getReminderScheduleModeCandidates(canUseExactAlarms: true)) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(effectiveDate, tz.local),
          reminderNotificationDetails,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: _matchDateTimeComponents(recurrence),
        );
        return true;
      } catch (e) {
        lastError = e;
        debugPrint('Reminder schedule attempt failed with mode $mode: $e');
      }
    }

    debugPrint('Failed to schedule reminder after fallback attempts: $lastError');
    return false;
  }

  DateTime _effectiveScheduleDate(
    DateTime scheduledDate,
    RecurringInterval? recurrence, {
    int? customIntervalValue,
    CustomIntervalUnit? customIntervalUnit,
  }) {
    if (recurrence == null || recurrence == RecurringInterval.none) {
      return scheduledDate;
    }
    if (recurrence != RecurringInterval.custom) {
      return scheduledDate;
    }
    if (!scheduledDate.isBefore(DateTime.now())) {
      return scheduledDate;
    }
    return AppDateUtils.calculateNextOccurrence(
          scheduledDate,
          recurrence,
          customValue: customIntervalValue,
          customUnit: customIntervalUnit,
        ) ??
        scheduledDate;
  }

  DateTimeComponents? _matchDateTimeComponents(RecurringInterval? recurrence) {
    if (recurrence == null || recurrence == RecurringInterval.none || recurrence == RecurringInterval.custom) {
      return null;
    }
    switch (recurrence) {
      case RecurringInterval.daily:
        return DateTimeComponents.time;
      case RecurringInterval.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RecurringInterval.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
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
    await _notificationsPlugin.cancel(id);
  }
}
