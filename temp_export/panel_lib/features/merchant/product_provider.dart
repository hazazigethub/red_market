import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart'; // ✅ استيراد الموديل لضمان قراءة وقت التجهيز

// ✅ مزود لجلب قائمة العروض الخاصة بالتاجر الحالي من السيرفر
// تم تحويله ليستخدم ProductModel بدلاً من Map لضمان ظهور وقت التجهيز
final merchantProductsProvider =
    FutureProvider<List<ProductModel>>((ref) async {
  final supabase = Supabase.instance.client;

  // التأكد من وجود مستخدم مسجل دخول حالياً
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  try {
    // جلب البيانات من جدول products
    // تم استخدام select('*') لضمان جلب عمود prep_time_minutes
    final response = await supabase
        .from('products')
        .select('*')
        .eq('merchant_id', user.id)
        .order('created_at', ascending: false);

    // ✅ التحويل باستخدام ProductModel لضمان قراءة حقل prep_time_minutes
    return (response as List)
        .map((json) => ProductModel.fromJson(json))
        .toList();
  } catch (e) {
    // في حال حدوث خطأ في الاتصال بالسيرفر
    throw Exception('حدث خطأ أثناء جلب العروض: $e');
  }
});

