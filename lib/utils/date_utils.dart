import 'package:intl/intl.dart';

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
}
