import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

import 'merchant_nav.dart';
import 'products_page.dart';
import 'manage_reels_page.dart';
import 'merchant_reports_page.dart';
import 'merchant_promo_page.dart';
import 'merchant_subscriptions_page.dart';
import 'merchant_ads_page.dart';
import 'merchant_campaign_page.dart';
import 'notifications_page.dart';
import 'store_settings_page.dart';
import 'merchant_bank_account_page.dart';
import 'useful_links_page.dart';

class MerchantHomePage extends StatefulWidget {
  const MerchantHomePage({super.key});

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  /// -1 يعني شاشة الترحيب
  int _index = -1;

  static const String _secKey = 'rm_sec_merchant';

  /// يعيدك للقسم الذي كنت فيه قبل تحديث الصفحة
  Future<void> _restoreSection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final i = prefs.getInt(_secKey);
      if (i != null && i >= -1 && i < _sections.length && mounted) {
        setState(() => _index = i);
      }
    } catch (_) {
      // التخزين قد يكون معطّلاً — نبدأ من الترحيب
    }
  }

  void _setSection(int i) {
    if (i < -1 || i >= _sections.length) return;
    setState(() => _index = i);
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_secKey, i))
        .catchError((_) => false);
  }


  /// بنرات أوقفتها الإدارة ولم يطّلع عليها التاجر
  List<Map<String, dynamic>> _suspendedBanners = [];

  /// الحملة الموسمية النشطة
  Map<String, dynamic>? _campaign;
  int _campaignProducts = 0;

  @override
  void initState() {
    super.initState();
    _restoreSection();
    MerchantNav.requested.addListener(_onNavRequest);
    _loadFeatures();
    _loadSuspended();
    _loadCampaign();
  }

  /// يجلب الحملة النشطة وعدد عروض التاجر فيها
  Future<void> _loadCampaign() async {
    try {
      final res = await Supabase.instance.client.rpc('get_active_campaign');
      if (res == null) return;

      final c = Map<String, dynamic>.from(res as Map);
      final uid = Supabase.instance.client.auth.currentUser?.id;

      int mine = 0;
      if (uid != null) {
        final rows = await Supabase.instance.client
            .from('campaign_product_stats')
            .select('id')
            .eq('campaign_id', c['id'])
            .eq('merchant_id', uid)
            .eq('current_status', 'active');
        mine = (rows as List).length;
      }

      if (!mounted) return;
      setState(() {
        _campaign = c;
        _campaignProducts = mine;
      });
    } catch (e) {
      debugPrint('Campaign banner error: $e');
    }
  }

  /// يجلب البنرات الموقوفة لعرض تنبيه
  Future<void> _loadSuspended() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final res = await Supabase.instance.client
          .from('banner_bookings')
          .select('id, rejection_reason, final_price, banner_type')
          .eq('merchant_id', uid)
          .eq('status', 'suspended')
          .order('reviewed_at', ascending: false)
          .limit(3);

      if (!mounted) return;
      setState(() {
        _suspendedBanners = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Suspended load error: $e');
    }
  }

  @override
  void dispose() {
    MerchantNav.requested.removeListener(_onNavRequest);
    super.dispose();
  }

  /// ينتقل للقسم المطلوب من شاشة أخرى
  void _onNavRequest() {
    final target = MerchantNav.requested.value;
    if (target == null || !mounted) return;
    _setSection(target);
    MerchantNav.clear();
  }

  /// أقسام مرتبطة بميزات تُفتح من لوحة الأدمن
  /// المفتاح رقم القسم، والقيمة اسم العمود في system_settings
  static const _gated = <int, String>{
    3: 'feat_promo',
    4: 'feat_banners',
    5: 'feat_campaigns',
  };

  /// ما هو مفتوح فعلياً — يُملأ عند التحميل
  Map<String, bool> _features = const {};

  Future<void> _loadFeatures() async {
    try {
      final data = await Supabase.instance.client
          .from('system_settings')
          .select('feat_promo, feat_banners, feat_campaigns')
          .eq('id', 1)
          .maybeSingle();

      if (data == null || !mounted) return;
      setState(() {
        _features = {
          for (final k in _gated.values) k: data[k] == true,
        };
      });
    } catch (_) {
      // تعذّر الجلب — تبقى الأقسام مغلقة
    }
  }

  bool _isLocked(int i) {
    final key = _gated[i];
    if (key == null) return false;
    return _features[key] != true;
  }

  static const _sections = <Map<String, dynamic>>[
    {'label': 'عروضي', 'icon': Icons.inventory_2_outlined},
    {'label': 'الريلز', 'icon': Icons.video_library_outlined},
    {'label': 'التقارير', 'icon': Icons.bar_chart_outlined},
    {'label': 'رسائل المتابعين', 'icon': Icons.campaign_outlined},
    {'label': 'بنراتي', 'icon': Icons.ad_units_outlined},
    {'label': 'الحملة الموسمية', 'icon': Icons.local_fire_department_outlined},
    {'label': 'الاشتراكات', 'icon': Icons.card_membership_outlined},
    {'label': 'الإشعارات', 'icon': Icons.notifications_outlined},
    {'label': 'إعدادات المتجر', 'icon': Icons.settings_outlined},
    {'label': 'رصيد المتجر', 'icon': Icons.account_balance_wallet_outlined},
    {'label': 'روابط مفيدة', 'icon': Icons.link_outlined},
  ];

  Widget _sectionBody(int i) {
    if (_isLocked(i)) return _comingSoon(i);

    switch (i) {
      case 0:
        return const ProductsPage();
      case 1:
        return const ManageReelsPage();
      case 2:
        return const MerchantReportsPage();
      case 3:
        return const MerchantPromoPage();
      case 4:
        return const MerchantAdsPage();
      case 5:
        return const MerchantCampaignPage();
      case 6:
        return const MerchantSubscriptionsPage();
      case 7:
        return const NotificationsPage();
      case 8:
        return const StoreSettingsPage();
      case 9:
        return const MerchantBankAccountPage();
      case 10:
        return const UsefulLinksPage();
      default:
        return _welcome();
    }
  }

  /// تُعرض بدل القسم حتى تُفتح ميزته من لوحة الأدمن
  Widget _comingSoon(int i) {
    final s = _sections[i];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(s['icon'] as IconData,
                  size: 30, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 18),
            Text(
              s['label'] as String,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('قريباً',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand)),
            ),
            const SizedBox(height: 14),
            Text(
              'هذه الخدمة قيد التجهيز، وستُفتح للتجار قريباً.\nسنُشعرك فور إتاحتها.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  height: 1.9,
                  color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== الإحصاءات =====================

  Future<int> _count(String table, String col) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 0;
      final res = await Supabase.instance.client
          .from(table)
          .select('id')
          .eq(col, uid)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _followers() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 0;
      final res = await Supabase.instance.client
          .from('merchants')
          .select('followers_count')
          .eq('id', uid)
          .maybeSingle();
      return (res?['followers_count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ===================== شاشة الترحيب =====================

  /// بنر الحملة الموسمية
  Widget _campaignBanner() {
    final c = _campaign!;
    final daysLeft = (c['days_left'] as num?)?.toInt() ?? 0;
    final total = (c['product_count'] as num?)?.toInt() ?? 0;
    final joined = _campaignProducts > 0;

    return InkWell(
      onTap: () => MerchantNav.goTo(MerchantNav.campaignSection),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD32027), Color(0xFF8E1010)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32027).withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (c['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysLeft > 0 ? 'باقٍ $daysLeft يوم' : 'آخر يوم',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              joined
                  ? 'لديك $_campaignProducts عرض في الحملة — أضف المزيد لزيادة ظهورك'
                  : 'اعرض ما لديك في صفحة الحملة أمام كل زوّار المنصة',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.9,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 15, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 7),
                Text(
                  '$total عرض في الحملة',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        joined ? 'إدارة عروضي' : 'شارك الآن',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD32027),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_left_rounded,
                          size: 17, color: Color(0xFFD32027)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة تنبيه ببنر أوقفته الإدارة
  Widget _suspendedAlert(Map<String, dynamic> b) {
    final reason = (b['rejection_reason'] ?? '').toString();
    final price = (b['final_price'] as num?)?.toStringAsFixed(2) ?? '0';
    final type = b['banner_type'] == 'wide' ? 'العريض' : 'الصغير';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.block_rounded,
                    color: Colors.red, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'أُوقف بنرك $type',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => MerchantNav.goTo(MerchantNav.adsSection),
                child: const Text(
                  'عرض بنراتي',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
              ),
            ],
          ),

          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reason,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.9, color: Color(0xFF4A5468)),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 14, color: Colors.green),
              const SizedBox(width: 7),
              Text(
                'أُعيد مبلغ $price ر.س إلى رصيد متجرك',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // ===== تنبيه البنرات الموقوفة =====
              if (_suspendedBanners.isNotEmpty) ...[
                ..._suspendedBanners.map(_suspendedAlert),
                const SizedBox(height: 20),
              ],

              // ===== بنر الحملة الموسمية =====
              if (_campaign != null) ...[
                _campaignBanner(),
                const SizedBox(height: 28),
              ],

              Text(
                'مرحباً بك في متجرك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر قسماً من القائمة لإدارة متجرك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = 16.0;
                  final cols = c.maxWidth >= 800
                      ? 4
                      : c.maxWidth >= 520
                          ? 2
                          : 1;
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;

                  final stats = [
                    _stat('عروضي', _count('products', 'merchant_id')),
                    _stat('الريلز', _count('reels', 'merchant_id')),
                    _stat('زيارات متجري',
                        _count('analytics_visits', 'merchant_id')),
                    _stat('المتابعون', _followers()),
                  ];

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    alignment: WrapAlignment.center,
                    children: stats
                        .map((s) => SizedBox(width: w, child: s))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, Future<int> future) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            FutureBuilder<int>(
              future: future,
              builder: (context, snap) => Text(
                snap.hasData ? '${snap.data}' : '—',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand),
              ),
            ),
          ],
        ),
      );

  // ===================== القائمة الجانبية =====================

  Widget _sideMenu() {
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        itemCount: _sections.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _menuItem(
              label: 'الرئيسية',
              icon: Icons.dashboard_outlined,
              selected: _index == -1,
              onTap: () => _setSection(-1),
            );
          }

          final s = _sections[i - 1];
          return _menuItem(
            label: s['label'] as String,
            icon: s['icon'] as IconData,
            selected: _index == i - 1,
            locked: _isLocked(i - 1),
            onTap: () => _setSection(i - 1),
          );
        },
      ),
    );
  }

  Widget _menuItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color:
                        selected ? Colors.white : const Color(0xFF8A93A6)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected
                          ? Colors.white
                          : locked
                              ? const Color(0xFFA5ADBB)
                              : const Color(0xFF4A5468),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (locked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFF0F1F4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('قريباً',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF8A93A6))),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== البناء =====================

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          if (wide) _sideMenu(),
          Expanded(
            child: Container(
              color: const Color(0xFFF7F8FA),
              child: Column(
                children: [
                  // شريط اختيار الأقسام على الشاشات الضيقة
                  if (!wide)
                    SizedBox(
                      height: 54,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _sections.length + 1,
                        itemBuilder: (context, i) {
                          final selected =
                              (i == 0 && _index == -1) || _index == i - 1;
                          final label = i == 0
                              ? 'الرئيسية'
                              : _sections[i - 1]['label'] as String;
                          final locked = i > 0 && _isLocked(i - 1);

                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  _setSection(i == 0 ? -1 : i - 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.brand
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.brand
                                          : Colors.grey.shade300),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  locked ? '$label · قريباً' : label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? Colors.white
                                        : locked
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Expanded(child: _sectionBody(_index)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
