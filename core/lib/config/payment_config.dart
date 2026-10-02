// lib/config/payment_config.dart

// ============================================================
// إعدادات Myratoorah
// ============================================================

class MyratoorahConfig {
  // 🔐 مفاتيح الوصول
  static const String apiKey =
      'SK_SAU_o0dX0F2pBUQ0BZhfA9dD0JZ5y3DOIvKJ4Khwfln0knYBy3I8dBcw2Pk5FqTB3vw6';
  static const String merchantId = 'red_market';

  // 📍 الروابط
  static const String baseUrl = 'https://api.myratoorah.com/v3';
  static const String webhookUrl = 'https://redmarket.api.com/webhooks/payment';

  // 💰 الإعدادات المالية
  static const double vatPercentage = 15.0;
  static const String currency = 'SAR';
  static const String language = 'ar';

  // 🌐 بيانات الشركة
  static const String companyName = 'Red Market';
  static const String companyEmail = 'redmarket.sa@outlook.com';
  static const String companyPhone = '+966592168600';
  static const String companyCity = 'Riyadh';
  static const String companyCountry = 'SA';
}

// ============================================================
// إعدادات الدفع
// ============================================================

class PaymentConfig {
  // ⏱️ المهل الزمنية
  static const int paymentTimeoutSeconds = 30;
  static const int retryAttempts = 3;
  static const int retryDelaySeconds = 5;

  // 🔄 حدود المدفوعات
  static const double minPaymentAmount = 10.0; // ر.س
  static const double maxPaymentAmount = 1000000.0; // ر.س

  // 📊 رسوم المعاملات (إذا كانت مطبقة)
  static const double transactionFeePercentage = 0.0; // بدون رسوم حالياً

  // 🎯 أنواع الدفع
  static const Map<String, String> paymentTypes = {
    'subscription': 'الاشتراك',
    'banner_booking': 'حجز البنر',
    'splash_ad': 'إعلان الشاشة الرئيسية',
  };

  // ✅ حالات الدفع
  static const Map<String, String> paymentStatuses = {
    'pending': 'قيد الانتظار',
    'processing': 'جاري المعالجة',
    'completed': 'مكتملة',
    'failed': 'فاشلة',
    'cancelled': 'ملغاة',
  };
}

// ============================================================
// إعدادات الفواتير
// ============================================================

class InvoiceConfig {
  // 🏢 تنسيق الفواتير
  static const String invoicePrefix = 'INV';
  static const String invoiceDateFormat = 'dd/MM/yyyy';
  static const String invoiceNumberFormat =
      'INV-{year}-{number}'; // مثال: INV-2024-001

  // 📅 الافتراضيات
  static const int defaultPaymentTermsDays = 30;
  static const double defaultVatPercentage = 15.0;

  // 📝 حالات الفواتير
  static const Map<String, String> invoiceStatuses = {
    'draft': 'مسودة',
    'issued': 'مُصدرة',
    'paid': 'مدفوعة',
    'partially_paid': 'مدفوعة جزئياً',
    'overdue': 'متأخرة',
    'cancelled': 'ملغاة',
  };

  // 📧 البريد الإلكتروني
  static const String invoiceFromEmail = 'invoices@redmarket.sa';
  static const String invoiceFromName = 'Red Market - الفواتير';
}

// ============================================================
// إعدادات الاشتراكات
// ============================================================

class SubscriptionConfig {
  // 📋 خطط الاشتراك (ستُجلب من قاعدة البيانات)
  static const Map<String, SubscriptionPlan> defaultPlans = {
    'basic': SubscriptionPlan(
      id: 'plan_basic',
      name: 'الخطة الأساسية',
      price: 99.00,
      durationDays: 30,
      productLimit: 50,
      reelsLimit: 10,
    ),
    'pro': SubscriptionPlan(
      id: 'plan_pro',
      name: 'خطة احترافية',
      price: 299.00,
      durationDays: 30,
      productLimit: 500,
      reelsLimit: 100,
    ),
    'enterprise': SubscriptionPlan(
      id: 'plan_enterprise',
      name: 'خطة المؤسسات',
      price: 999.00,
      durationDays: 30,
      productLimit: 5000,
      reelsLimit: 1000,
    ),
  };

  // 🎁 فترات التجربة المجانية
  static const int trialPeriodDays = 7;
  static const bool autoRenewDefault = true;
}

// ============================================================
// نموذج خطة الاشتراك
// ============================================================

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int durationDays;
  final int productLimit;
  final int reelsLimit;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.productLimit,
    required this.reelsLimit,
  });
}

// ============================================================
// إعدادات الاسترجاع
// ============================================================

class RefundConfig {
  // ⏱️ مدة صلاحية طلب الاسترجاع
  static const int refundRequestValidityDays = 30;

  // 📝 أسباب الاسترجاع الشائعة
  static const List<String> refundReasons = [
    'خطأ في الفاتورة',
    'دفع مكرر',
    'عدم الرضا عن الخدمة',
    'ألغيت الاشتراك',
    'أخرى',
  ];

  // 💰 حد أقصى لقيمة الاسترجاع الفوري (بدون موافقة)
  static const double autoRefundLimit = 100.0; // ر.س
}

// ============================================================
// إعدادات الإشعارات
// ============================================================

class PaymentNotificationConfig {
  // 📨 رسائل البريد الإلكتروني
  static const String paymentSuccessSubject = 'تأكيد استقبال الدفعة';
  static const String paymentFailureSubject = 'فشل عملية الدفع';
  static const String invoiceCreatedSubject = 'تم إنشاء فاتورة جديدة';
  static const String refundProcessedSubject = 'تم معالجة طلب الاسترجاع';

  // 📱 إشعارات الدفع
  static const bool sendEmailNotifications = true;
  static const bool sendPushNotifications = true;
  static const bool sendSmsNotifications = false;

  // ⏰ المواعيد
  static const int notificationDelaySeconds = 0; // فوري
}

// ============================================================
// إعدادات الأمان
// ============================================================

class SecurityConfig {
  // 🔐 التحقق من الـ Webhook
  static const bool verifyWebhookSignature = true;

  // 🛡️ تشفير البيانات الحساسة
  static const bool encryptSensitiveData = true;

  // 📊 تسجيل العمليات
  static const bool logPaymentTransactions = true;
  static const bool logWebhookEvents = true;

  // ⛔️ حدود الأمان
  static const int maxLoginAttempts = 5;
  static const int accountLockoutMinutes = 15;
}

// ============================================================
// إعدادات الإبلاغ
// ============================================================

class ReportingConfig {
  // 📊 التقارير اليومية
  static const bool sendDailyReports = true;
  static const String dailyReportTime = '09:00'; // 9:00 صباحاً

  // 📊 التقارير الأسبوعية
  static const bool sendWeeklyReports = true;
  static const String weeklyReportDay = 'monday'; // يوم الاثنين
  static const String weeklyReportTime = '10:00';

  // 📧 المتلقون
  static const List<String> reportRecipients = [
    'admin@redmarket.sa',
    'finance@redmarket.sa',
  ];
}

// ============================================================
// دالة مساعدة للحصول على رسالة الخطأ
// ============================================================

String getPaymentErrorMessage(String code) {
  const Map<String, String> errorMessages = {
    'INVALID_AMOUNT': 'المبلغ غير صحيح',
    'PAYMENT_TIMEOUT': 'انتهت مهلة الدفع',
    'INVALID_CARD': 'بيانات البطاقة غير صحيحة',
    'INSUFFICIENT_FUNDS': 'الرصيد غير كافي',
    'PAYMENT_DECLINED': 'تم رفض الدفع',
    'NETWORK_ERROR': 'خطأ في الاتصال',
    'UNKNOWN_ERROR': 'حدث خطأ غير متوقع',
  };

  return errorMessages[code] ?? 'حدث خطأ في المعالجة';
}

// ============================================================
// دالة مساعدة للحصول على رابط الدفع
// ============================================================

String getPaymentUrl(String sessionId) {
  return '${MyratoorahConfig.baseUrl}/payments/$sessionId';
}

// ============================================================
// ثوابت رسائل النجاح
// ============================================================

const String paymentSuccessMessage = '✅ تم استقبال دفعتك بنجاح';
const String invoiceCreatedMessage = '📄 تم إنشاء الفاتورة بنجاح';
const String refundInitiatedMessage = '💰 تم بدء معالجة طلب الاسترجاع';
const String subscriptionActivatedMessage = '🎯 تم تفعيل اشتراكك بنجاح';
