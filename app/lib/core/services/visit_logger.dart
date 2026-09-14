import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

/// تسجيل زيارات الصفحات في analytics_visits
///
/// موحّدة لكل المواضع — والمنصة تُحسب داخلها فلا تُنسى.
class VisitLogger {
  VisitLogger._();

  /// اسم المنصة الحالية
  static String get platform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }

  /// يسجّل زيارة صفحة
  ///
  /// [pageName] إلزامي — مثل: app_launch · store · category
  static Future<void> log({
    required String pageName,
    String? merchantId,
    String? categoryId,
    String? categoryName,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('analytics_visits').insert({
        'page_name': pageName,
        'platform': platform,
        'user_id': supabase.auth.currentUser?.id,
        'visited_at': DateTime.now().toIso8601String(),
        if (merchantId != null) 'merchant_id': merchantId,
        if (categoryId != null) 'category_id': categoryId,
        if (categoryName != null) 'category_name': categoryName,
      });
    } catch (e) {
      // الزيارة ليست حرجة — لا توقف التطبيق
      debugPrint('VisitLogger error: $e');
    }
  }
}
