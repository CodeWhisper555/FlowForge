import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static final DateFormat _shortDate = DateFormat('MMM d, y');
  static final DateFormat _dateTime = DateFormat('MMM d, y h:mm a');

  static String formatShortDate(DateTime? date) {
    if (date == null) return 'No due date';
    return _shortDate.format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Unknown';
    return _dateTime.format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return _shortDate.format(date);
    }
  }
}
