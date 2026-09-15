import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

import 'admin_newsletter_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_analytics_visits_screen.dart';
import 'admin_refunds_screen.dart';
import 'admin_merchant_banners_screen.dart';
import 'admin_splash_ads_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_campaigns_screen.dart';
import 'admin_financial_screen.dart';
import 'admin_users_hub_screen.dart';
import 'admin_catalog_hub_screen.dart';
import 'admin_billing_hub_screen.dart';
import 'admin_messages_hub_screen.dart';
import 'admin_support_hub_screen.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  /// -1 يعني شاشة الترحيب
  int _index = -1;

  static const _sections = <Map<String, dynamic>>[
    {'label': 'التقرير المالي', 'icon': Icons.payments_outlined},
    {'label': 'إدارة العملاء والتجار', 'icon': Icons.groups_outlined},
    {'label': 'العروض والتصنيفات', 'icon': Icons.inventory_2_outlined},
    {'label': 'الباقات وأكواد الخصم', 'icon': Icons.card_membership_outlined},
    {'label': 'طلبات الاسترداد', 'icon': Icons.replay_circle_filled_outlined},
    {'label': 'التواصل والدعم', 'icon': Icons.support_agent_outlined},
    {'label': 'النشرة الأسبوعية', 'icon': Icons.mail_outline_rounded},
    {'label': 'الإشعارات والإعلانات', 'icon': Icons.notifications_outlined},
    {'label': 'إعلان الشاشة الرئيسية', 'icon': Icons.smartphone_outlined},
    {'label': 'الحملات الموسمية', 'icon': Icons.campaign_outlined},
    {'label': 'بنرات التجار', 'icon': Icons.storefront_outlined},
    {'label': 'البنرات', 'icon': Icons.ad_units_outlined},
    {'label': 'الزيارات', 'icon': Icons.trending_up_outlined},
    {'label': 'الإعدادات', 'icon': Icons.settings_outlined},
  ];

  Widget _sectionBody(int i) {
    switch (i) {
      case 0:
        return const AdminFinancialScreen();
      case 1:
        return const AdminUsersHubScreen();
      case 2:
        return const AdminCatalogHubScreen();
      case 3:
        return const AdminBillingHubScreen();
      case 4:
        return const AdminRefundsScreen();
      case 5:
        return const AdminSupportHubScreen();
      case 6:
        return const AdminNewsletterScreen();
      case 7:
        return const AdminMessagesHubScreen();
      case 8:
        return const AdminSplashAdsScreen();
      case 9:
        return const AdminCampaignsScreen();
      case 10:
        return const AdminMerchantBannersScreen();
      case 11:
        return const AdminBannersScreen();
      case 12:
        return const AdminAnalyticsVisitsScreen();
      case 13:
        return const AdminSettingsScreen();
      default:
        return _welcome();
    }
  }

  // ===================== الإحصاءات =====================

  Future<int> _count(String table, [String? col, dynamic val]) async {
    try {
      // count بدل جلب الصفوف — يتجاوز حد الألف الافتراضي
      var q = Supabase.instance.client.from(table).select('id');
      if (col != null) q = q.eq(col, val);
      return await q.count(CountOption.exact).then((r) => r.count);
    } catch (_) {
      return 0;
    }
  }

  /// إجمالي زيارات اليوم
  Future<int> _todayVisits() async {
    try {
      final start = DateTime.now();
      final midnight =
          DateTime(start.year, start.month, start.day).toUtc().toIso8601String();

      final res = await Supabase.instance.client
          .from('analytics_visits')
          .select('id')
          .gte('visited_at', midnight)
          .count(CountOption.exact);

      return res.count;
    } catch (_) {
      return 0;
    }
  }

  // ===================== شاشة الترحيب =====================

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Text(
                'مرحباً بك في لوحة الإدارة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر قسماً من القائمة لإدارة المنصة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = 16.0;
                  final cols = c.maxWidth >= 1000
                      ? 3
                      : c.maxWidth >= 620
                          ? 2
                          : 1;
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;

                  final stats = [
                    _stat('العملاء', _count('profiles', 'role', 'customer')),
                    _stat('التجار', _count('profiles', 'role', 'merchant')),
                    _stat('العروض', _count('products')),
                    _stat('البلاغات', _count('reports', 'status', 'pending')),
                    _stat('بانتظار الفحص',
                        _count('merchants', 'is_verified', false)),
                    _stat('زيارات اليوم', _todayVisits()),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: future,
              builder: (context, snap) => Text(
                snap.hasData ? '${snap.data}' : '—',
                style: TextStyle(
                    fontSize: 28,
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
      width: 236,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        itemCount: _sections.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _menuItem(
              label: 'الرئيسية',
              icon: Icons.dashboard_outlined,
              selected: _index == -1,
              onTap: () => setState(() => _index = -1),
            );
          }

          final s = _sections[i - 1];
          return _menuItem(
            label: s['label'] as String,
            icon: s['icon'] as IconData,
            selected: _index == i - 1,
            onTap: () => setState(() => _index = i - 1),
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
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon,
                    size: 19,
                    color:
                        selected ? Colors.white : const Color(0xFF8A93A6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF4A5468),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
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

                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _index = i == 0 ? -1 : i - 1),
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
                                  label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? Colors.white
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
