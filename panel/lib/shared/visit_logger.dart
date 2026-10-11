import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تسجيل زيارات صفحات اللوحة في جدول analytics_visits.
///
/// زيارة واحدة لكل صفحة في الجلسة، حتى لا تتضخّم الأرقام
/// عند إعادة بناء الصفحة أو تحديثها داخل التطبيق.
/// لا يوقف الصفحة عند الفشل.
class PanelVisitLogger {
  PanelVisitLogger._();

  static final Set<String> _logged = <String>{};

  static Future<void> log(String page) async {
    if (_logged.contains(page)) return;
    _logged.add(page);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('analytics_visits').insert({
        'page_name': page,
        'platform': 'panel',
        'user_id': supabase.auth.currentUser?.id,
        'visited_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('PanelVisitLogger error: $e');
      _logged.remove(page); // يسمح بمحاولة لاحقة
    }
  }
}
