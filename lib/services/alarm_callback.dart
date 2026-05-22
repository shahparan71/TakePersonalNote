import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';

/// Key prefix for storing notification metadata in SharedPreferences.
const String _notifMetaPrefix = 'notif_meta_';

/// Top-level callback invoked by AndroidAlarmManager in a background isolate.
@pragma('vm:entry-point')
void alarmCallback(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final metaJson = prefs.getString('$_notifMetaPrefix$alarmId');
  if (metaJson == null) return;

  final meta = jsonDecode(metaJson) as Map<String, dynamic>;
  final title = meta['title'] as String? ?? 'Reminder';
  final body = meta['body'] as String? ?? '';
  final payload = meta['payload'] as String?;
  final recurrenceType = meta['recurrence'] as String?;
  final customValue = meta['customIntervalValue'] as int?;
  final customUnit = meta['customIntervalUnit'] as String?;

  // Initialize flutter_local_notifications in background isolate
  final flnPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flnPlugin.initialize(initSettings);

  // Show the notification
  await flnPlugin.show(
    alarmId,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        channelDescription: 'Task reminders',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        showWhen: true,
        icon: 'app_icon_2',
        color: Color(0xFF6366F1),
      ),
    ),
    payload: payload,
  );

  // Handle recurring: reschedule next occurrence
  if (recurrenceType != null && recurrenceType != 'none') {
    final scheduledMs = meta['scheduledDateMs'] as int?;
    if (scheduledMs != null) {
      final originalDate = DateTime.fromMillisecondsSinceEpoch(scheduledMs);
      final nextDate = _calculateNext(originalDate, recurrenceType, customValue, customUnit);
      if (nextDate != null) {
        // Update stored metadata with new scheduled date
        meta['scheduledDateMs'] = nextDate.millisecondsSinceEpoch;
        await prefs.setString('$_notifMetaPrefix$alarmId', jsonEncode(meta));

        final delay = nextDate.difference(DateTime.now());
        if (delay.isNegative) return;
        await AndroidAlarmManager.oneShot(
          delay,
          alarmId,
          alarmCallback,
          exact: true,
          allowWhileIdle: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }
    }
  } else {
    // One-shot: clean up metadata
    await prefs.remove('$_notifMetaPrefix$alarmId');
  }
}

DateTime? _calculateNext(
  DateTime from,
  String recurrenceType,
  int? customValue,
  String? customUnit,
) {
  switch (recurrenceType) {
    case 'daily':
      return from.add(const Duration(days: 1));
    case 'weekly':
      return from.add(const Duration(days: 7));
    case 'monthly':
      return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
    case 'custom':
      if (customValue == null || customUnit == null) return null;
      switch (customUnit) {
        case 'days':
          return from.add(Duration(days: customValue));
        case 'weeks':
          return from.add(Duration(days: customValue * 7));
        case 'months':
          return DateTime(from.year, from.month + customValue, from.day, from.hour, from.minute);
        default:
          return null;
      }
    default:
      return null;
  }
}
