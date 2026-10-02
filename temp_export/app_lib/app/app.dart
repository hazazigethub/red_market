import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/routing/app_router.dart';
import 'package:flutter/services.dart';

// ✅ provider الثيم المستمر مع SharedPreferences
final appThemeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';
    final isDark = prefs.getBool('theme_dark_$userId') ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'guest';
    await prefs.setBool('theme_dark_$userId', !isDark);
  }

  Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    final isDark = prefs.getBool('theme_dark_$userId') ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

// ✅ aliases للتوافق مع الكود القديم
final localeProvider = StateProvider<String>((ref) => 'ar');
final userRoleProvider = StateProvider<String?>((ref) => null);
final adminThemeModeProvider = appThemeModeProvider;
final merchantThemeModeProvider = appThemeModeProvider;
final customerThemeModeProvider = appThemeModeProvider;

final currentUserProfileProvider = StreamProvider<String?>((ref) async* {
  final prefs = await SharedPreferences.getInstance();
  final cachedRole = prefs.getString('user_role');
  if (cachedRole != null) {
    ref.read(userRoleProvider.notifier).state = cachedRole;
    debugPrint("✅ تم استرجاع الرتبة المحفوظة: $cachedRole");
  }

  final stream = Supabase.instance.client.auth.onAuthStateChange;
  await for (final authState in stream) {
    final user =
        authState.session?.user ?? Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ref.read(userRoleProvider.notifier).state = null;
      await prefs.remove('user_role');
      yield null;
      continue;
    }

    // ✅ تحميل الثيم الخاص بالمستخدم عند تسجيل الدخول
    await ref.read(appThemeModeProvider.notifier).setUserId(user.id);

    final currentRole = ref.read(userRoleProvider);
    if (currentRole != null) {
      yield null;
      continue;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (response != null && response['role'] != null) {
        final role = response['role'] as String;
        ref.read(userRoleProvider.notifier).state = role;
        await prefs.setString('user_role', role);
        debugPrint("🎯 تم تحديث الرتبة: $role");
      }
    } catch (e) {
      debugPrint("❌ فشل جلب الرتبة: $e");
    }
    yield null;
  }
});

class LocalApp extends ConsumerWidget {
  const LocalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final localeCode = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);
    ref.watch(currentUserProfileProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'LOCAL',
      locale: Locale(localeCode),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor:
              brightness == Brightness.dark ? Colors.black : Colors.white,
          systemNavigationBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ));
        return child!;
      },
    );
  }
}
