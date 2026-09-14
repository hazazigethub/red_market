import 'package:intl/intl.dart';

class AppDateTimeFormatter {
  // دالة تحويل الوقت من UTC (قاعدة البيانات) إلى التوقيت المحلي (12 ساعة)
  static String formatTime(String timeStr) {
    try {
      String cleanTime = timeStr.trim();
      DateTime now = DateTime.now();
      DateTime? parsedTime;

      // محاولة قراءة الصيغ المختلفة
      List<String> formats = ["HH:mm:ss", "HH:mm", "H:mm"];
      for (var format in formats) {
        try {
          DateTime tempDate = DateFormat(format).parse(cleanTime);
          // نعتبر الوقت القادم هو UTC
          parsedTime = DateTime.utc(now.year, now.month, now.day, tempDate.hour,
              tempDate.minute, tempDate.second);
          break;
        } catch (_) {}
      }

      if (parsedTime != null) {
        // نحوله للمحلي وننسقه
        return DateFormat('hh:mm a').format(parsedTime.toLocal());
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  // دالة لتنسيق التاريخ
  static String formatDate(DateTime date) {
    return DateFormat('hh:mm a').format(date.toLocal());
  }
}
