import 'package:intl/intl.dart';
import 'package:take_personal_note/models/recurring_interval.dart';

class AppDateUtils {
  static String formatReminder(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateToCompare = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String time = DateFormat('h:mm a').format(dateTime);

    if (dateToCompare == today) {
      return 'Today $time';
    } else if (dateToCompare == tomorrow) {
      return 'Tomorrow $time';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  static DateTime? calculateNextOccurrence(
    DateTime? current,
    RecurringInterval interval, {
    int? customValue,
    CustomIntervalUnit? customUnit,
  }) {
    if (current == null || interval == RecurringInterval.none) return null;

    final now = DateTime.now();
    DateTime next = current;

    // Always advance to the *next* occurrence, since current is the *initial* or *last* one.
    next = _addInterval(next, interval, customValue: customValue, customUnit: customUnit);

    // If it's still in the past, catch up to the current time.
    while (next.isBefore(now)) {
      next = _addInterval(next, interval, customValue: customValue, customUnit: customUnit);
    }
    
    return next;
  }

  static DateTime _addInterval(
    DateTime date,
    RecurringInterval interval, {
    int? customValue,
    CustomIntervalUnit? customUnit,
  }) {
    switch (interval) {
      case RecurringInterval.daily:
        return date.add(const Duration(days: 1));
      case RecurringInterval.weekly:
        return date.add(const Duration(days: 7));
      case RecurringInterval.monthly:
        return DateTime(date.year, date.month + 1, date.day, date.hour, date.minute);
      case RecurringInterval.custom:
        final val = customValue ?? 1;
        switch (customUnit ?? CustomIntervalUnit.days) {
          case CustomIntervalUnit.days:
            return date.add(Duration(days: val));
          case CustomIntervalUnit.weeks:
            return date.add(Duration(days: 7 * val));
          case CustomIntervalUnit.months:
            return DateTime(date.year, date.month + val, date.day, date.hour, date.minute);
        }
      default:
        return date;
    }
  }
}
