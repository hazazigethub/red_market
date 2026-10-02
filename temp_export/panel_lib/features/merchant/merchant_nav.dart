import 'package:flutter/foundation.dart';

/// مؤشر بسيط للتنقّل بين أقسام لوحة التاجر
class MerchantNav {
  MerchantNav._();

  /// رقم قسم بنراتي في القائمة
  static const int adsSection = 4;

  /// رقم قسم الحملة الموسمية في القائمة
  static const int campaignSection = 5;

  /// رقم قسم رصيد المتجر في القائمة
  static const int walletSection = 9;

  /// يُشعر لوحة التاجر بطلب الانتقال لقسم معيّن
  static final ValueNotifier<int?> requested = ValueNotifier<int?>(null);

  /// يطلب الانتقال إلى قسم
  static void goTo(int index) => requested.value = index;

  /// يُستهلك الطلب بعد تنفيذه
  static void clear() => requested.value = null;
}
