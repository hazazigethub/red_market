import 'package:flutter/widgets.dart';

/// إعداد المدخل — يُضبط مرة واحدة في runPanel قبل تشغيل التطبيق.
/// ملف مشترك: لا يستورد أي شاشة من التاجر أو الإدارة.
class AppConfig {
  AppConfig._();

  /// الدور الوحيد المسموح له في هذا المدخل: 'merchant' أو 'super_admin'
  static String role = 'merchant';

  /// يبني لوحة هذا المدخل بعد نجاح الدخول
  static Widget Function() dashboard = () => const SizedBox.shrink();

  static bool get isAdmin => role == 'super_admin';
}
