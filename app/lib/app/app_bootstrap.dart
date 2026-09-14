import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ ملاحظة: تأكد من إنشاء ملف StorageService ليعمل هذا الاستيراد
// import 'package:red_market/core/services/storage_service.dart';

class AppBootstrap {
  /// دالة لتهيئة كل شيء قبل إطلاق التطبيق
  static Future<ProviderContainer> createContainer() async {
    // التأكد من تهيئة روابط Flutter قبل أي عملية أخرى
    WidgetsFlutterBinding.ensureInitialized();

    // 1. تهيئة SharedPreferences (تسخين الـ singleton قبل إطلاق التطبيق)
    await SharedPreferences.getInstance();

    // 2. إنشاء حاوية Riverpod مع التعديلات (Overrides)
    final container = ProviderContainer(
      overrides: [
        // ✅ هنا سيتم ربط مزود التخزين بقيمة الـ prefs المهيأة
        // storageServiceProvider.overrideWithValue(StorageService(prefs)),
      ],
    );

    // 3. قراءة الإعدادات المحفوظة
    // هنا يمكن إضافة دوال لقراءة حالة "وضع الصيانة" أو "اللغة الافتراضية"
    // التي تم تحديدها من قبل الأدمن سابقاً.

    return container;
  }
}
