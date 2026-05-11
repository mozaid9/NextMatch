import 'package:intl/intl.dart';

class DateTimeHelpers {
  const DateTimeHelpers._();

  static String formatMatchDateTime(DateTime dateTime) {
    return DateFormat('EEE d MMM - HH:mm').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('EEE d MMM yyyy').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins mins';
  }

  static DateTime combineDateAndTime(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
