class RoutePaths {
  // 1. مسارات البداية والترحيب
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // 2. مسارات المصادقة (Auth)
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String interestsSelection = '/interests-selection';
  static const String merchantRegister = '/merchant-register';

  // 3. مسارات العميل الأساسية (Customer Main)
  static const String home = '/';
  static const String reels = '/reels';
  static const String storeDetails = '/store-details';
  static const String productDetails = '/product-details';
  static const String customerHome = '/customer-home';

  // ✅ مسار البحث
  static const String searchResults = '/search-results';
  static const String subCategories = '/sub-categories';

  // ✅ مسار المناطق
  static const String region = '/region/:regionName';

  // 4. مسارات المعلومات والدعم
  static const String personalInfo = '/personal-info';
  static const String faq = '/faq';
  static const String customerService = '/customer-service';
  static const String privacyPolicy = '/privacy-policy';
  // تم توحيد termsConditions هنا واستخدامها لاحقاً لمنع التكرار "Already Defined"
  static const String termsConditions = '/terms-conditions';

  // 5. مسارات التسوّق والعمليات للعميل (Commerce)
  static const String favourites = '/favourites';
  static const String profile = '/profile';
  static const String interests = '/interests';

  // 6. مسارات التاجر (Merchant Dashboard)
  static const String merchantHome = '/merchant-dashboard';
  static const String storeSettings = '/store-settings';
  static const String deleteAccount = '/delete-account';
  static const String paymentSelection = '/payment-selection';

  // 7. إدارة المحتوى والأدوات الخاصة بالتاجر
  static const String manageReels = '/manage-reels';

  // 8. التفاعل والتواصل
  static const String notifications = '/notifications';
  static const String chat = '/chat';
  static const String merchantChat = '/merchant-chat';

  // 9. روابط إضافية
  static const String usefulLinks = '/useful-links';
  static const String mapPicker = '/map-picker';

  // 🔑 10. مسارات الإدارة (Admin Dashboard)
  static const String adminDashboard = '/admin-dashboard';

  static const String adminCategories = '/admin-categories';
  static const String adminNotifications = '/admin-notifications';
  static const String adminBanners = '/admin-banners';
  static const String adminProductsControl = '/admin-products';
  static const String adminSettings = '/admin-settings';
  static const String maintenance = '/maintenance';
  static const String adminUsers = '/admin-users';
  static const String adminMerchants = '/admin-merchants';

  // ملاحظة: تم الإبقاء على مسميات فريدة هنا لمنع التعارض مع termsConditions العامة
  static const String customerTerms = '/customerTerms';
  static const String merchantTerms = '/merchantTerms';

  static const String adminCreateSubscription = '/admin-create-subscription';

  static const String adminAnalyticsUsers = '/admin-analytics-users';
  static const String adminAnalyticsMerchants = '/admin-analytics-merchants';
  static const String adminAnalyticsProducts = '/admin-Analytics-products';
  static const String adminAnalyticsvisits = '/admin-analytics-Visits';
  static const String adminAnalyticsMerchantCategories =
      '/admin-analytics-merchant-categories';
  static const String adminAnalyticsProductCategories =
      '/admin-analytics-product-categories';

  static const String adminReports = '/admin-reports';

  static const String merchantStoreDirect = '/merchant-store/:merchantId';
  static const String productDetailsDirect = '/product-details/:id';
}
