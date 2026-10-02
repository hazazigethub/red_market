import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إعلان الافتتاح — تحميل مسبق وعرض من الجهاز
class SplashAdService {
  SplashAdService._();
  static final SplashAdService instance = SplashAdService._();

  static const _keyOpenCount = 'splash_open_count';
  static const _keyLastShown = 'splash_last_shown';
  static const _keyCachedDate = 'splash_cached_date';
  static const _keyCachedId = 'splash_cached_id';
  static const _keyCachedTarget = 'splash_cached_target';
  static const _keyCachedProduct = 'splash_cached_product';
  static const _keyCachedMerchant = 'splash_cached_merchant';

  /// لا يظهر الإعلان قبل الفتحة الرابعة
  static const _minOpens = 3;

  final supabase = Supabase.instance.client;

  /// يزيد عدّاد فتحات التطبيق
  Future<int> bumpOpenCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = (prefs.getInt(_keyOpenCount) ?? 0) + 1;
      await prefs.setInt(_keyOpenCount, n);
      return n;
    } catch (e) {
      debugPrint('Open count error: $e');
      return 0;
    }
  }

  /// مسار الصورة المخزّنة ليوم معيّن
  Future<File?> _cachedFile(String date) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/splash_$date.img');
      return await f.exists() ? f : null;
    } catch (e) {
      debugPrint('Cache path error: $e');
      return null;
    }
  }

  /// يجلب إعلان اليوم إن توفّرت شروط العرض
  /// يُرجع null إن لم يكن ثمة ما يُعرض
  Future<SplashAdData?> getTodayAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateKey(DateTime.now());

      // شرط 1: لم يُعرض اليوم
      if (prefs.getString(_keyLastShown) == today) return null;

      // شرط 2: تجاوز الفتحات الأولى
      final opens = prefs.getInt(_keyOpenCount) ?? 0;
      if (opens <= _minOpens) return null;

      // شرط 3: الصورة مخزّنة لهذا اليوم
      if (prefs.getString(_keyCachedDate) != today) return null;

      final file = await _cachedFile(today);
      if (file == null) return null;

      final id = prefs.getString(_keyCachedId);
      if (id == null) return null;

      return SplashAdData(
        id: id,
        file: file,
        targetType: prefs.getString(_keyCachedTarget) ?? 'store',
        productId: prefs.getString(_keyCachedProduct),
        merchantId: prefs.getString(_keyCachedMerchant),
      );
    } catch (e) {
      debugPrint('Get today ad error: $e');
      return null;
    }
  }

  /// يُعلّم أن الإعلان عُرض اليوم
  Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastShown, _dateKey(DateTime.now()));
    } catch (e) {
      debugPrint('Mark shown error: $e');
    }
  }

  /// يحمّل إعلان الغد في الخلفية — يُستدعى بعد إقلاع التطبيق
  Future<void> preloadTomorrow() async {
    try {
      final res = await supabase.rpc('get_tomorrow_splash_ad');
      if (res == null) return;

      final ad = Map<String, dynamic>.from(res as Map);
      final url = (ad['image_url'] ?? '').toString();
      final date = (ad['ad_date'] ?? '').toString();
      if (url.isEmpty || date.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();

      // مخزّن بالفعل
      if (prefs.getString(_keyCachedDate) == date) return;

      // تنزيل الصورة
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) return;

      final bytes = await consolidateHttpClientResponseBytes(resp);
      client.close();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/splash_$date.img');
      await file.writeAsBytes(bytes);

      await prefs.setString(_keyCachedDate, date);
      await prefs.setString(_keyCachedId, (ad['id'] ?? '').toString());
      await prefs.setString(
          _keyCachedTarget, (ad['target_type'] ?? 'store').toString());

      final pid = ad['product_id'];
      if (pid != null) {
        await prefs.setString(_keyCachedProduct, pid.toString());
      } else {
        await prefs.remove(_keyCachedProduct);
      }

      final mid = ad['merchant_id'];
      if (mid != null) {
        await prefs.setString(_keyCachedMerchant, mid.toString());
      } else {
        await prefs.remove(_keyCachedMerchant);
      }

      await _cleanOld(dir, date);

      debugPrint('✅ حُمّل إعلان الغد');
    } catch (e) {
      debugPrint('Preload error: $e');
    }
  }

  /// يحذف صور الأيام القديمة
  Future<void> _cleanOld(Directory dir, String keep) async {
    try {
      final files = dir.listSync();
      for (final f in files) {
        final name = f.path.split(Platform.pathSeparator).last;
        if (name.startsWith('splash_') &&
            !name.contains(keep) &&
            f is File) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('Clean error: $e');
    }
  }

  // ===== التتبّع =====

  Future<void> trackImpression(String id) =>
      _track('track_splash_impression', id);

  Future<void> trackSkip(String id) => _track('track_splash_skip', id);

  Future<void> trackClick(String id) => _track('track_splash_click', id);

  Future<void> _track(String fn, String id) async {
    try {
      await supabase.rpc(fn, params: {'p_ad_id': id});
    } catch (e) {
      debugPrint('$fn error: $e');
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// بيانات إعلان جاهز للعرض
class SplashAdData {
  final String id;
  final File file;
  final String targetType;
  final String? productId;
  final String? merchantId;

  const SplashAdData({
    required this.id,
    required this.file,
    required this.targetType,
    this.productId,
    this.merchantId,
  });
}
