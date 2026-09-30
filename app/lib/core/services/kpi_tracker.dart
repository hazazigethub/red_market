import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visit_logger.dart';

/// تسجيل أحداث مؤشرات الأداء: الانتقال إلى المتجر، والبحث
class KpiTracker {
  KpiTracker._();

  static Timer? _searchTimer;
  static String? _lastSearch;

  /// انتقال العميل إلى متجر التاجر
  /// source: product (زر العرض) أو store (رابط المتجر)
  static Future<void> storeClick({
    String? productId,
    String? merchantId,
    String source = 'product',
  }) async {
    try {
      await Supabase.instance.client.from('store_clicks').insert({
        'product_id': productId,
        'merchant_id': merchantId,
        'source': source,
        'platform': VisitLogger.platform,
      });
    } catch (e) {
      debugPrint('KpiTracker.storeClick error: $e');
    }
  }

  /// البحث أثناء الكتابة: يُسجَّل بعد توقف الكتابة ثانية ونصف
  static void search(String query, int resultsCount) {
    final q = query.trim();
    _searchTimer?.cancel();
    if (q.length < 2) return;
    _searchTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (q == _lastSearch) return;
      _lastSearch = q;
      try {
        await Supabase.instance.client.from('search_logs').insert({
          'query': q.length > 200 ? q.substring(0, 200) : q,
          'results_count': resultsCount,
          'platform': VisitLogger.platform,
        });
      } catch (e) {
        debugPrint('KpiTracker.search error: $e');
      }
    });
  }
}
