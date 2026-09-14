import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/core/services/splash_ad_service.dart';
import 'package:red_market/app/app_providers.dart';

import 'splash_ad_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// إعلان الافتتاح إن توفّر
  SplashAdData? _ad;
  bool _showingAd = false;

  @override
  void initState() {
    super.initState();
    _handleInitialFlow();
  }

  Future<void> _handleInitialFlow() async {
    // عدّاد فتحات التطبيق — الإعلان لا يظهر للمستخدم الجديد
    await SplashAdService.instance.bumpOpenCount();

    // فحص إعلان اليوم أثناء انتظار السبلاش — بلا تأخير إضافي
    final adFuture = SplashAdService.instance.getTodayAd();

    // 1. انتظار بسيط لضمان استقرار استعادة الجلسة من الذاكرة المحلية
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    // حالة (أ): لا توجد جلسة مخزنة - نترك الروتر يوجه للـ Login تلقائياً
    if (session == null) {
      debugPrint("Auth Check: No Session Found");
      SplashAdService.instance.preloadTomorrow();

      final guestAd = await adFuture;
      if (guestAd != null && mounted) {
        setState(() {
          _ad = guestAd;
          _showingAd = true;
        });
        return;
      }

      ref.read(splashDoneProvider.notifier).state = true;
      if (mounted) {
        context.go(RoutePaths.login);
      }
      return;
    }

    try {
      // حالة (ب): جلب البيانات لتحديث الحالة فقط
      final userData = await supabase
          .from('profiles')
          .select('is_banned, role')
          .eq('id', session.user.id)
          .maybeSingle();

      debugPrint("Auth Check Result: $userData");

      if (userData != null && userData['is_banned'] == true) {
        debugPrint("Auth Check: User is Banned");
        await supabase.auth.signOut();
      } else {
        if (userData != null && userData['role'] != null) {
          ref.read(userRoleProvider.notifier).state = userData['role'];
          debugPrint("User Role Updated to: ${userData['role']}");
        }
        debugPrint("Auth Check: User is Clear");
      }
    } catch (e) {
      debugPrint("Auth Check Error: $e");
    }

    if (!mounted) return;

    // تحميل إعلان الغد في الخلفية — لا ننتظره
    SplashAdService.instance.preloadTomorrow();

    // عرض إعلان اليوم إن توفّر
    final ad = await adFuture;
    if (ad != null && mounted) {
      setState(() {
        _ad = ad;
        _showingAd = true;
      });
      return;
    }

    _goNext();
  }

  /// ينتقل للوجهة الصحيحة بعد الإعلان أو بدونه
  void _goNext() {
    if (!mounted) return;

    ref.read(splashDoneProvider.notifier).state = true;

    final target = Supabase.instance.client.auth.currentSession == null
        ? RoutePaths.login
        : RoutePaths.home;
    context.go(target);
  }

  /// عند الضغط على الإعلان
  void _openAdTarget(SplashAdData ad) {
    if (!mounted) return;

    ref.read(splashDoneProvider.notifier).state = true;

    if (ad.targetType == 'product' &&
        ad.productId != null &&
        ad.productId!.isNotEmpty) {
      context.go('/product-details/${ad.productId}');
    } else if (ad.merchantId != null && ad.merchantId!.isNotEmpty) {
      context.go('/merchant-store/${ad.merchantId}');
    } else {
      _goNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFFD32027);

    // ===== إعلان الافتتاح =====
    if (_showingAd && _ad != null) {
      return SplashAdScreen(
        ad: _ad!,
        onFinish: _goNext,
        onTap: _openAdTarget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الشعار المربّع
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Image.asset(
                    'assets/images/applogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.storefront_rounded,
                        size: 90,
                        color: brandColor),
                  ),
                ),

                const SizedBox(height: 24),

                // الشعار العريض
                SizedBox(
                  width: 230,
                  height: 80,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'RED MARKET',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: brandColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
