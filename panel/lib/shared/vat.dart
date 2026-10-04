// panel/lib/shared/vat.dart
// نسبة ضريبة القيمة المضافة الحالية من قاعدة البيانات:
// 15 عند وجود رقم ضريبي في الإعدادات، و0 عند عدم وجوده.
import 'package:supabase_flutter/supabase_flutter.dart';

class Vat {
  Vat._();

  /// النسبة المئوية الحالية (0 = لا ضريبة)
  static double rate = 0;

  /// نص النسبة للعرض، مثل "15%"
  static String get label => '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)}%';

  /// الضريبة على مبلغ قبل الضريبة
  static double on(double subtotal) => subtotal * rate / 100;

  static Future<double> load() async {
    try {
      final r = await Supabase.instance.client.rpc('current_vat_rate');
      rate = ((r as num?) ?? 0).toDouble();
    } catch (_) {
      // عند التعذّر يبقى آخر قيمة معروفة؛ الخادم هو من يحسب المبلغ النهائي
    }
    return rate;
  }
}
