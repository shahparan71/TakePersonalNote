import 'dart:io';
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const _channel = MethodChannel('com.take_personal_note/battery_optimization');

  /// Returns true if the app is already ignoring battery optimizations.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Shows the system dialog to request ignoring battery optimizations.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Opens the battery optimization settings page.
  static Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
