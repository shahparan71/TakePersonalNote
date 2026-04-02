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

  static DateTime? calculateNextOccurrence(DateTime? current, RecurringInterval interval) {
    if (current == null || interval == RecurringInterval.none) return null;

    final now = DateTime.now();
    DateTime next = current;

    while (next.isBefore(now)) {
      switch (interval) {
        case RecurringInterval.daily:
          next = next.add(const Duration(days: 1));
          break;
        case RecurringInterval.weekly:
          next = next.add(const Duration(days: 7));
          break;
        case RecurringInterval.monthly:
          // Use Jiffy or manual math to add a month. For simplicity, we'll use 30 days or DateTime constructor.
          next = DateTime(next.year, next.month + 1, next.day, next.hour, next.minute);
          break;
        default:
          return null;
      }
    }
    return next;
  }
}
