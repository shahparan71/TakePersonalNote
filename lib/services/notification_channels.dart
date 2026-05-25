import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String reminderChannelId = 'reminders_channel';
const String reminderChannelName = 'Reminders';

/// Ensures the reminders notification channel exists (required on Android 8+).
Future<void> ensureReminderChannel(FlutterLocalNotificationsPlugin plugin) async {
  if (!Platform.isAndroid) return;
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  const channel = AndroidNotificationChannel(
    reminderChannelId,
    reminderChannelName,
    description: 'Task and note reminders',
    importance: Importance.max,
  );
  await android.createNotificationChannel(channel);
}

const AndroidNotificationDetails reminderAndroidDetails = AndroidNotificationDetails(
  reminderChannelId,
  reminderChannelName,
  channelDescription: 'Task and note reminders',
  importance: Importance.max,
  priority: Priority.high,
  ticker: 'ticker',
  showWhen: true,
  icon: 'app_icon_2',
  largeIcon: DrawableResourceAndroidBitmap('app_icon_2'),
  color: Color(0xFF6366F1),
);

const NotificationDetails reminderNotificationDetails = NotificationDetails(
  android: reminderAndroidDetails,
);
