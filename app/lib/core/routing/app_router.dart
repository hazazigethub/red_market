import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/app/app.dart' hide userRoleProvider;
import 'package:red_market/app/app_providers.dart';

import 'package:red_market/features/customer/home/presentation/pages/home_screen.dart'
    as customer;

import 'package:red_market/features/customer/home/presentation/pages/campaign_page.dart';
import 'package:red_market/features/splash/presentation/splash_screen.dart';
import 'package:red_market/features/customer/customer_terms_page.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market_core/red_market_core.dart';

import 'package:red_market/features/auth/presentation/login_screen.dart';
import 'package:red_market/features/auth/presentation/register_screen.dart';
import 'package:red_market/features/auth/presentation/forgot_password_screen.dart';
import 'package:red_market/features/auth/presentation/otp_screen.dart';

import 'package:red_market/features/customer/home/presentation/pages/interests_selection_screen.dart';
import 'package:red_market/features/customer/home/presentation/pages/store_details_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/notifications_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/personal_information_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/customer_service_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/product_details_page.dart';

import 'package:red_market/features/customer/home/presentation/pages/faq_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/privacy_policy_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/delete_account_page.dart';
import 'package:red_market/features/customer/home/presentation/pages/sub_categories_screen.dart';
import 'package:red_market/features/customer/home/presentation/pages/customer_interests_page.dart';
import 'package:red_market/features/customer/maintenance_screen.dart';

// كاش وضع الصيانة: يمنع استعلام قاعدة البيانات عند كل تنقل
bool? _maintenanceCache;
DateTime? _maintenanceCachedAt;
const Duration _maintenanceTtl = Duration(minutes: 1);

Future<bool> _isMaintenanceOn() async {
  final now = DateTime.now();
  if (_maintenanceCache != null &&
      _maintenanceCachedAt != null &&
      now.difference(_maintenanceCachedAt!) < _maintenanceTtl) {
    return _maintenanceCache!;
  }
  try {
    // دالة SECURITY DEFINER: تتجاوز RLS وترجع قيمة منطقية واحدة فقط
    final result = await Supabase.instance.client.rpc('get_maintenance_status');
    _maintenanceCache = (result as bool?) ?? false;
  } catch (e) {
    debugPrint('Maintenance check failed: $e');
    // فشل الاستعلام لا يوقف التنقل
    _maintenanceCache ??= false;
  }
  _maintenanceCachedAt = now;
  return _maintenanceCache!;
}

// ✅ يجب أن يكون هذا الكلاس قبل routerProvider
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    // استمع لتغييرات Auth
    _authSub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());

    // استمع لتغييرات userRole
    ref.listen<String?>(userRoleProvider, (_, __) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _authSub;

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // ✅ notifier بدل ref.watch لمنع إعادة إنشاء الـ router
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: !kReleaseMode,
    refreshListenable: notifier,
    redirect: (context, state) async {
      final userRole = ref.read(userRoleProvider);
      final splashDone = ref.read(splashDoneProvider);
      final session = Supabase.instance.client.auth.currentSession;
      final bool isLoggedIn = session != null;
      final String loc = state.matchedLocation;

      // شاشة الصيانة نفسها مستثناة دائماً لتفادي حلقة إعادة توجيه
      if (loc == RoutePaths.maintenance) return null;

      // شاشة البداية تبقى ظاهرة حتى تنتهي مدتها
      if (loc == RoutePaths.splash && !splashDone) return null;

      // فحص وضع الصيانة (مع كاش) قبل أي شيء آخر
      final bool isMaintenance = await _isMaintenanceOn();
      if (isMaintenance && userRole != 'super_admin') {
        return RoutePaths.maintenance;
      }

      if (!isLoggedIn) {
        final bool isAllowedForGuest = loc == RoutePaths.home ||
            loc == '/' ||
            loc == RoutePaths.login ||
            loc == RoutePaths.register ||
            loc == RoutePaths.otp ||
            loc == RoutePaths.forgotPassword ||
            loc == RoutePaths.splash ||
            loc == RoutePaths.customerTerms ||
            loc == RoutePaths.subCategories ||
            loc == '/campaign' ||
            loc.contains('/product-details') ||
            loc.contains('/merchant-store/') ||
            loc.startsWith(RoutePaths.storeDetails);

        if (isAllowedForGuest) return null;
        return RoutePaths.login;
      }

      if (loc == RoutePaths.splash ||
          loc == RoutePaths.login ||
          loc == RoutePaths.otp) {
        return RoutePaths.home;
      }

      if (loc == RoutePaths.register) return null;

      return null;
    },
    routes: [
      GoRoute(
          path: RoutePaths.maintenance,
          builder: (context, state) => const MaintenanceScreen()),
      GoRoute(
          path: RoutePaths.splash,
          builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const customer.HomeScreen()),
      GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: RoutePaths.register,
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: RoutePaths.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: RoutePaths.otp,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic> ||
              extra['phoneNumber'] is! String) {
            return const LoginScreen();
          }
          return OtpScreen(
            phoneNumber: extra['phoneNumber'] as String,
            isMerchant: (extra['isMerchant'] as bool?) ?? false,
          );
        },
      ),
      GoRoute(
          path: RoutePaths.interestsSelection,
          builder: (context, state) => const InterestsSelectionScreen()),
      GoRoute(
        path: RoutePaths.subCategories,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SubCategoriesScreen(
            parentId: extra?['parentId'] ?? '',
            categoryName: extra?['categoryName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/product-details',
        builder: (context, state) {
          final product =
              state.extra is ProductModel ? state.extra as ProductModel : null;
          return ProductDetailsPage(product: product);
        },
      ),
      GoRoute(
        path: '/product-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          final product =
              state.extra is ProductModel ? state.extra as ProductModel : null;
          return ProductDetailsPage(productId: id, product: product);
        },
      ),
      GoRoute(
        path: '/merchant-store/:merchantId',
        builder: (context, state) {
          final mId = state.pathParameters['merchantId'];
          return StoreDetailsPage(merchantId: mId ?? '');
        },
      ),
      GoRoute(
        path: RoutePaths.storeDetails,
        builder: (context, state) {
          if (state.extra is MerchantModel) {
            return StoreDetailsPage(
                merchantId: (state.extra as MerchantModel).id);
          }
          final queryId = state.uri.queryParameters['id'];
          return StoreDetailsPage(merchantId: queryId ?? '');
        },
      ),
      GoRoute(
          path: RoutePaths.interests,
          builder: (context, state) => const CustomerInterestsPage()),
      GoRoute(
          path: RoutePaths.faq, builder: (context, state) => const FAQPage()),
      GoRoute(
          path: RoutePaths.privacyPolicy,
          builder: (context, state) => const PrivacyPolicyPage()),
      GoRoute(
          path: RoutePaths.deleteAccount,
          builder: (context, state) => const DeleteAccountPage()),
      GoRoute(
          path: RoutePaths.notifications,
          builder: (context, state) => const NotificationsPage()),
      GoRoute(
          path: RoutePaths.personalInfo,
          builder: (context, state) => const PersonalInformationPage()),
      GoRoute(
          path: RoutePaths.customerService,
          builder: (context, state) => const CustomerServicePage()),
      GoRoute(
          path: '/campaign', builder: (context, state) => const CampaignPage()),
      GoRoute(
        path: RoutePaths.customerTerms,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CustomerTermsPage(
            content: extra?['content'],
            version: extra?['version'],
            isMandatory: extra != null,
          );
        },
      ),
    ],
  );
});
