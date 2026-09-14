import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Providers الأساسية لـ RED OCEAN ---

// 1. مزود الثيم (Theme Mode) — يُحمَّل من SharedPreferences
final isDarkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier();
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';
    final isDark = prefs.getBool('theme_dark_$userId') ?? false;
    state = isDark;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';
    await prefs.setBool('theme_dark_$userId', state);
  }

  Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    final isDark = prefs.getBool('theme_dark_$userId') ?? false;
    state = isDark;
  }
}

// 2. مزود اللغة (Locale)
final localeProvider = StateProvider<String>((ref) => 'ar');

// 3. حالة المصادقة (Auth State)
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

// ✅ 4. مزود رتبة المستخدم (User Role Provider)
final userRoleProvider = StateProvider<String?>((ref) => null);

// ✅ 5. مزود حالة لوحة التحكم
final isAdminModeProvider = StateProvider<bool>((ref) => false);

// ✅ 6. علامة انتهاء شاشة البداية
// يبقى false حتى تنتهي مدة السبلاش، فيمنع الراوتر من تخطّيها
final splashDoneProvider = StateProvider<bool>((ref) => false);
