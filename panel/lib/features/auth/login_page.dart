import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import '../../shell/dashboard_shell.dart';
import 'merchant_register_page.dart';
import 'account_recovery_page.dart';
import '../admin/categories_page.dart';
import '../admin/admin_home_page.dart';
import '../admin/new_merchants_screen.dart';
import '../admin/admin_banners_screen.dart';
import '../admin/admin_announcements_screen.dart';
import '../merchant/merchant_home_page.dart';
import '../merchant/manage_reels_page.dart';
import '../merchant/products_page.dart';
import '../merchant/review_reels_page.dart';
import '../merchant/merchant_reports_page.dart';
import '../merchant/merchant_promo_page.dart';
import '../merchant/merchant_subscriptions_page.dart';
import '../merchant/store_preview_page.dart';
import '../merchant/notifications_page.dart' as merchant_notif;
import '../merchant/useful_links_page.dart';
import '../merchant/store_settings_page.dart';
import '../merchant/merchant_bank_account_page.dart';
import '../admin/admin_analytics_visits_screen.dart';
import '../admin/admin_customer_screen.dart';
import '../admin/admin_products_screen.dart';
import '../admin/admin_merchants_screen.dart';
import '../admin/admin_analytics_merchants_screen.dart';
import '../admin/admin_analytics_products_screen.dart';
import '../admin/admin_reports_screen.dart';
import '../admin/admin_settings_screen.dart';
import '../admin/admin_notifications_screen.dart';
import '../admin/admin_newsletter_screen.dart';
import '../admin/discount_codes_screen.dart';
import '../admin/maintenance_screen.dart';
import '../admin/admin_analytics_customer_screen.dart';
import '../admin/admin_analytics_merchant_categories_screen.dart';
import '../admin/admin_analytics_product_categories_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  /// ظهور متتابع لعناصر اللوح الجانبي
  late final AnimationController _revealCtrl;

  /// مزايا اللوحة
  static const _highlights = <(IconData, String, String)>[
    (
      Icons.inventory_2_outlined,
      'أدر عروضك',
      'أضف عروضك وعدّلها ونظّمها في تصنيفات خاصة بمتجرك',
    ),
    (
      Icons.insights_outlined,
      'تابع نتائجك',
      'زيارات متجرك، أعلى عروضك تفاعلاً، ومقارنة أدائك بالسوق',
    ),
    (
      Icons.campaign_outlined,
      'صل لمتابعيك',
      'أرسل عروضك مباشرة لمن يتابع متجرك، وانشر مقاطع تعرّف بها',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
  }

  /// ظهور تدريجي بتأخير لكل عنصر
  Widget _reveal({required int order, required Widget child}) {
    final start = (order * 0.16).clamp(0.0, 0.7);
    final curve = CurvedAnimation(
      parent: _revealCtrl,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - curve.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }


  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  /// يحوّل رسائل الخطأ الإنجليزية إلى العربية
  String _arabicError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login')) {
        return 'رقم الجوال أو كلمة المرور غير صحيحة';
      }
      if (msg.contains('email not confirmed')) {
        return 'لم يتم تأكيد الحساب بعد';
      }
      if (msg.contains('too many') || msg.contains('rate limit')) {
        return 'محاولات كثيرة، انتظر قليلاً ثم حاول مجدداً';
      }
      if (msg.contains('user not found')) {
        return 'لا يوجد حساب بهذا الرقم';
      }
      return 'تعذر تسجيل الدخول، حاول مجدداً';
    }

    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException')) {
      return 'تعذر الاتصال، تحقق من الشبكة';
    }

    // رسائلنا العربية تمر كما هي
    return text.replaceAll('Exception: ', '');
  }

  Future<void> _login() async {
    if (_phone.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الجوال وكلمة المرور');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final supabase = Supabase.instance.client;
    try {
      final clean = _phone.text.trim().replaceAll(RegExp(r'\D'), '');

      // يجلب بريد المصادقة المرتبط بالجوال — حقيقياً كان أو مولّداً
      String? email;
      try {
        final found =
            await supabase.rpc('get_login_email', params: {'p_phone': clean});
        email = found?.toString();
      } catch (e) {
        debugPrint('get_login_email error: $e');
      }

      if (email == null || email.isEmpty) {
        throw 'لا يوجد حساب بهذا الرقم';
      }

      final res = await supabase.auth.signInWithPassword(
        email: email, password: _password.text.trim());

      final uid = res.user?.id;
      if (uid == null) throw 'تعذر تسجيل الدخول';

      final profile = await supabase
          .from('profiles')
          .select('role, deletion_scheduled_at')
          .eq('id', uid)
          .maybeSingle();
      final role = profile?['role']?.toString();

      if (role != 'super_admin' && role != 'merchant') {
        await supabase.auth.signOut();
        throw 'هذه اللوحة مخصصة للتجار والإدارة فقط';
      }
      // حساب مجدول للحذف: نعرض شاشة الاستعادة بدل اللوحة
      final scheduledRaw = profile?['deletion_scheduled_at'];
      final scheduled = scheduledRaw == null
          ? null
          : DateTime.tryParse(scheduledRaw.toString());

      if (scheduled != null && mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        nav.pushReplacement(MaterialPageRoute(
          builder: (_) => AccountRecoveryPage(
            scheduledAt: scheduled,
            onRestored: () {
              // سياق جذري محفوظ — لا يعتمد على صفحة أُزيلت
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ));
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => DashboardShell(
            role: role!,
            items: role == 'merchant'
                ? const [
                    NavItem('الرئيسية', Icons.dashboard, MerchantHomePage()),
                    NavItem('عروضي', Icons.inventory_2, ProductsPage()),
                    NavItem('الريلز', Icons.video_library, ManageReelsPage()),
                    NavItem('التقارير', Icons.bar_chart, MerchantReportsPage()),
                    NavItem('رسائل المتابعين', Icons.campaign, MerchantPromoPage()),
                    NavItem('الاشتراكات', Icons.card_membership, MerchantSubscriptionsPage()),
                    NavItem('الإشعارات', Icons.notifications, merchant_notif.NotificationsPage()),
                    NavItem('إعدادات المتجر', Icons.settings, StoreSettingsPage()),
                    NavItem('الحساب البنكي', Icons.account_balance, MerchantBankAccountPage()),
                    NavItem('روابط مفيدة', Icons.link, UsefulLinksPage()),
                  ]
                : const [
              NavItem('الرئيسية', Icons.dashboard, AdminHomePage()),
              NavItem('التصنيفات', Icons.category, AdminCategoriesScreen()),
              NavItem('إدارة العملاء', Icons.people, AdminUsersScreen()),
              NavItem('إدارة التجار', Icons.storefront, AdminMerchantsScreen()),
              NavItem('التجار الجدد', Icons.fiber_new_outlined, NewMerchantsScreen()),
              NavItem('إدارة العروض', Icons.inventory, AdminProductsScreen()),
              NavItem('تحليلات العملاء', Icons.analytics, AdminAnalyticsUsersScreen()),
              NavItem('تصنيفات المتاجر', Icons.storefront, AdminAnalyticsMerchantCategoriesScreen()),
              NavItem('تصنيفات العروض', Icons.inventory_2, AdminAnalyticsProductCategoriesScreen()),
              NavItem('الإشعارات', Icons.notifications, AdminNotificationsScreen()),
              NavItem('النشرة الأسبوعية', Icons.campaign, AdminNewsletterScreen()),
              NavItem('أكواد الخصم', Icons.local_offer, DiscountCodesScreen()),
              NavItem('التجار', Icons.store, AdminAnalyticsMerchantsScreen()),
              NavItem('العروض', Icons.shopping_bag, AdminAnalyticsProductsScreen()),
              NavItem('البلاغات', Icons.flag, AdminReportsScreen()),
              NavItem('الزيارات', Icons.trending_up, AdminAnalyticsVisitsScreen()),
              NavItem('البنرات', Icons.ad_units, AdminBannersScreen()),
              NavItem('الإعلانات', Icons.campaign, AdminAnnouncementsScreen()),
              NavItem('الإعدادات', Icons.settings, AdminSettingsScreen()),
            ],
          ),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _arabicError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// نافذة استعادة كلمة المرور
  void _showForgotDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.brand),
              const SizedBox(width: 10),
              const Text('استعادة كلمة المرور',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Text(
              'تواصل مع الدعم الفني عبر واتساب أو البريد الإلكتروني، '
              'وسنساعدك في استعادة الوصول لحسابك خلال يوم عمل. '
              'جهّز رقم جوالك المسجّل ورقم سجلك التجاري للتحقق.',
              style: TextStyle(fontSize: 13.5, height: 1.9),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Row(
            children: [
              if (wide) Expanded(flex: 5, child: _sidePanel()),
              Expanded(flex: 4, child: _form()),
            ],
          ),
        ),
      ),
    );
  }

  /// اللوح التعريفي الأحمر
  Widget _sidePanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand, const Color(0xFF8E1010)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reveal(
                order: 0,
                child: const Text(
                  'لوحة تحكم متجرك',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _reveal(
                order: 1,
                child: Text(
                  'من هنا تدير عروضك ومقاطعك، وتتابع زوّار متجرك، '
                  'وتصل إلى متابعيك مباشرة.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 2.0,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),

              const SizedBox(height: 44),

              ..._highlights.asMap().entries.map(
                    (e) => _reveal(
                      order: 2 + e.key,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.15)),
                              ),
                              child: Icon(e.value.$1,
                                  color: Colors.white, size: 19),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.value.$2,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.value.$3,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.8,
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// نموذج الدخول
  Widget _form() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الشعار المربّع
              Center(
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: SvgPicture.asset(
                    'assets/images/applogo.svg',
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // الشعار العريض
              Center(
                child: SizedBox(
                  width: 210,
                  height: 70,
                  child: SvgPicture.asset(
                    'assets/images/red_market_logo.svg',
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => Text(
                      'رد ماركت',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'أهلاً بعودتك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'سجّل دخولك لإدارة متجرك',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 34),

              _field(
                controller: _phone,
                label: 'رقم الجوال',
                icon: Icons.phone_android_rounded,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _password,
                label: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: Colors.grey.shade500,
                  ),
                ),
                onSubmit: _loading ? null : _login,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12.5,
                              height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('دخول',
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _linkButton(
                    'ليس لديك متجر؟',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const MerchantRegisterPage())),
                  ),
                  _linkButton('نسيت كلمة المرور؟', _showForgotDialog),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// رابط نصي بلون الهوية
  Widget _linkButton(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.brand,
        ),
      ),
    );
  }

  /// حقل إدخال موحّد
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      ),
    );
  }
}
