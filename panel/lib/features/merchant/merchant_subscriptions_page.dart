import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import 'package:red_market_core/red_market_core.dart';
import 'merchant_checkout_page.dart';
import 'merchant_invoices_page.dart';
import 'merchant_auto_renew_page.dart';
import 'merchant_cancel_subscription_page.dart';

// 1. مزود البيانات - جلب الباقات النشطة فقط وتصفيتها بدقة حسب السعر
final adminPlansProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await Supabase.instance.client
      .from('subscription_plans')
      .select()
      .eq('is_active', true) // جلب الباقات المفعلة فقط من قبل الأدمن
      .order('price', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

/// هل التاجر مؤهل للفترة التجريبية؟ (لا سجلّ اشتراك سابق)
final trialEligibleProvider = FutureProvider<bool>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  final rows = await Supabase.instance.client
      .from('merchant_subscriptions')
      .select('id')
      .eq('merchant_id', userId)
      .limit(1);

  return (rows as List).isEmpty;
});

// ✅ مضاف: مزود لجلب الباقة الحالية للتاجر
final currentMerchantPlanProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  final profile = await Supabase.instance.client
      .from('profiles')
      .select('plan_id, subscription_end_date')
      .eq('id', userId)
      .maybeSingle();

  if (profile == null || profile['plan_id'] == null) return null;

  final plan = await Supabase.instance.client
      .from('subscription_plans')
      .select('id, price, name, plan_type, duration_days')
      .eq('id', profile['plan_id'])
      .maybeSingle();

  if (plan == null) return null;
  final result = {
    ...plan,
    'subscription_end_date': profile['subscription_end_date'],
  };
  debugPrint("✅ Plan Data: $result");
  return result;
});

// ✅ مضاف: Enum لحالات الباقة
enum _PlanStatus { current, downgrade, upgrade, available }

class MerchantSubscriptionsPage extends ConsumerStatefulWidget {
  const MerchantSubscriptionsPage({super.key});

  @override
  ConsumerState<MerchantSubscriptionsPage> createState() =>
      _MerchantSubscriptionsPageState();
}

class _MerchantSubscriptionsPageState
    extends ConsumerState<MerchantSubscriptionsPage> {
  /// دورة الفوترة لكل نوع باقة على حدة
  final Map<String, bool> _yearlyByType = {};

  /// القسم السفلي المفتوح: -1 يعني لا شيء

  bool _startingTrial = false;

  /// يفعّل الفترة التجريبية — 3 شهور على الأساسية
  Future<void> _startTrial() async {
    if (_startingTrial) return;
    setState(() => _startingTrial = true);

    try {
      final res = await Supabase.instance.client.rpc('start_trial');
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        ref.invalidate(trialEligibleProvider);
        ref.invalidate(currentMerchantPlanProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'بدأت فترتك التجريبية — 3 شهور مجاناً',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              map['error']?.toString() ?? 'تعذر التفعيل',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر التفعيل، حاول مجدداً',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _startingTrial = false);
    }
  }

  int _selectedPlanIndex = 0;
  final Color brandRed = const Color(0xFFD32027);
  final Color darkCard = const Color(0xFF1E1E1E);

  // ✅ مضاف: دالة تحديد حالة الباقة
  /// ترتيب مستويات الباقات: الأساسية أدنى والاحترافية أعلى
  int _typeRank(String? type) {
    switch (type) {
      case 'basic':
        return 1;
      case 'growth':
        return 2;
      case 'pro':
        return 3;
      default:
        return 0;
    }
  }

  _PlanStatus _getPlanStatus(
    Map<String, dynamic> plan,
    Map<String, dynamic>? currentPlan,
  ) {
    if (currentPlan == null) return _PlanStatus.available;

    final String currentPlanId = currentPlan['id'].toString();
    final String thisPlanId = plan['id'].toString();
    if (currentPlanId == thisPlanId) return _PlanStatus.current;

    // المقارنة بمستوى الباقة أولاً، لا بالسعر
    final int currentRank = _typeRank(currentPlan['plan_type']?.toString());
    final int planRank = _typeRank(plan['plan_type']?.toString());

    if (planRank < currentRank) return _PlanStatus.downgrade;
    if (planRank > currentRank) return _PlanStatus.upgrade;

    // نفس المستوى: السنوي ترقية عن الشهري، والعكس تخفيض
    final int currentDays =
        (currentPlan['duration_days'] as num?)?.toInt() ?? 30;
    final int planDays = (plan['duration_days'] as num?)?.toInt() ?? 30;

    if (planDays > currentDays) return _PlanStatus.upgrade;
    return _PlanStatus.downgrade;
  }

  // ✅ مضاف: نص الزر حسب الحالة
  String _getButtonLabel(_PlanStatus status) {
    switch (status) {
      case _PlanStatus.current:
        return "باقتك الحالية";
      case _PlanStatus.downgrade:
        return "غير متاح (تخفيض)";
      case _PlanStatus.upgrade:
        return "ترقية الباقة ↑";
      case _PlanStatus.available:
        return "اشتراك الآن";
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminPlansProvider);
    final currentPlanAsync = ref.watch(currentMerchantPlanProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        body: plansAsync.when(
          data: (plans) {
            if (plans.isEmpty) return _buildEmptyState();
            final currentPlan = currentPlanAsync.value;
            return RefreshIndicator(
              onRefresh: () async {
                ref.refresh(adminPlansProvider);
                ref.refresh(currentMerchantPlanProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const gap = 16.0;
                        final cols = c.maxWidth >= 1100
                            ? 3
                            : c.maxWidth >= 720
                            ? 2
                            : 1;
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        // نجمع الباقات حسب النوع: كل نوع بطاقة واحدة
                        final grouped = <String, List<Map<String, dynamic>>>{};
                        for (final p in plans) {
                          final type = (p['plan_type'] ?? 'other').toString();
                          grouped
                              .putIfAbsent(type, () => [])
                              .add(Map<String, dynamic>.from(p));
                        }

                        const order = ['basic', 'growth', 'pro'];
                        final types = grouped.keys.toList()
                          ..sort((a, b) {
                            final ia = order.indexOf(a);
                            final ib = order.indexOf(b);
                            return (ia == -1 ? 99 : ia).compareTo(
                              ib == -1 ? 99 : ib,
                            );
                          });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTabs(),
                            const SizedBox(height: 22),
                            cols >= types.length
                                ? IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: _spaced(
                                        List.generate(types.length, (index) {
                                          final type = types[index];
                                          final group = grouped[type]!;

                                          // الشهرية والسنوية داخل النوع نفسه
                                          final monthly = group.firstWhere(
                                            (p) =>
                                                ((p['duration_days'] as num?)
                                                        ?.toInt() ??
                                                    30) <
                                                365,
                                            orElse: () => group.first,
                                          );
                                          final yearly = group.firstWhere(
                                            (p) =>
                                                ((p['duration_days'] as num?)
                                                        ?.toInt() ??
                                                    30) >=
                                                365,
                                            orElse: () => <String, dynamic>{},
                                          );

                                          final hasYearly = yearly.isNotEmpty;
                                          final isYearly =
                                              _yearlyByType[type] == true &&
                                              hasYearly;
                                          final plan = isYearly
                                              ? yearly
                                              : monthly;

                                          return _buildModernPlanCard(
                                            context,
                                            index: index,
                                            plan: plan,
                                            isDark: isDark,
                                            currentPlan: currentPlan,
                                            planType: type,
                                            hasYearly: hasYearly,
                                            isYearly: isYearly,
                                            stretch: true,
                                          );
                                        }),
                                        gap,
                                        w,
                                      ),
                                    ),
                                  )
                                : Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    children: List.generate(types.length, (
                                      index,
                                    ) {
                                      final type = types[index];
                                      final group = grouped[type]!;
                                      final monthly = group.firstWhere(
                                        (p) =>
                                            ((p['duration_days'] as num?)
                                                    ?.toInt() ??
                                                30) <
                                            365,
                                        orElse: () => group.first,
                                      );
                                      final yearly = group.firstWhere(
                                        (p) =>
                                            ((p['duration_days'] as num?)
                                                    ?.toInt() ??
                                                30) >=
                                            365,
                                        orElse: () => <String, dynamic>{},
                                      );
                                      final hasYearly = yearly.isNotEmpty;
                                      final isYearly =
                                          _yearlyByType[type] == true &&
                                          hasYearly;
                                      final plan = isYearly ? yearly : monthly;

                                      return SizedBox(
                                        width: w,
                                        child: _buildModernPlanCard(
                                          context,
                                          index: index,
                                          plan: plan,
                                          isDark: isDark,
                                          currentPlan: currentPlan,
                                          planType: type,
                                          hasYearly: hasYearly,
                                          isYearly: isYearly,
                                        ),
                                      );
                                    }),
                                  ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () =>
              Center(child: CircularProgressIndicator(color: brandRed)),
          error: (e, _) => Center(child: Text("حدث خطأ ما: $e")),
        ),
      ),
    );
  }

  Widget _buildModernPlanCard(
    BuildContext context, {
    required int index,
    required Map<String, dynamic> plan,
    required bool isDark,
    Map<String, dynamic>? currentPlan,
    String planType = '',
    bool hasYearly = false,
    bool isYearly = false,
    bool stretch = false,
  }) {
    bool isSelected = _selectedPlanIndex == index;

    // السعر المكتوب هو الأصلي (المشطوب)
    final double oldPrice = (plan['price'] as num).toDouble();
    final int discountPercent = plan['discount_percent'] ?? 0;

    // السعر بعد الخصم — بلا كسور
    final double currentPrice = discountPercent > 0
        ? (oldPrice * (1 - (discountPercent / 100))).floorToDouble()
        : oldPrice;

    final status = _getPlanStatus(plan, currentPlan);
    final bool isDisabled =
        status == _PlanStatus.current || status == _PlanStatus.downgrade;

    // الباقة الحالية ملوّنة، والباقي رمادي
    final bool isCurrent = status == _PlanStatus.current;
    final Color accent =
        isCurrent ? brandRed : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? darkCard : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? brandRed.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isCurrent
                ? brandRed
                : isSelected
                ? const Color(0xFFCBD2DC)
                : const Color(0xFFE5E7EB),
            width: isCurrent ? 1.8 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ارتفاع محجوز — فتتساوى البطاقات وإن خلت من التبويبات
                    SizedBox(
                      height: 44,
                      child: hasYearly
                          ? _cardBillingToggle(planType, isYearly, isDark)
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // الاسم والسعر والخصم في سطر واحد
                    SizedBox(
                      height: 42,
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _planBaseName(plan['name'].toString()),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                              if (status == _PlanStatus.current &&
                                  currentPlan?['subscription_end_date'] != null)
                                Text(
                                  "ينتهي: ${DateTime.parse(currentPlan!['subscription_end_date']).day}/${DateTime.parse(currentPlan['subscription_end_date']).month}/${DateTime.parse(currentPlan['subscription_end_date']).year}",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 9.5,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        if (currentPrice <= 0)
                          Text(
                            "مجاني",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                              color: accent,
                            ),
                          )
                        else
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (discountPercent > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            accent.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        "وفر $discountPercent%",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 9.5,
                                          color: accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    PriceWidget(
                                      price: oldPrice,
                                      fontSize: 11,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    "${currentPrice.toInt()}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Cairo',
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Image.asset(
                                    'assets/images/sar_symbol.png',
                                    height: 13,
                                    width: 13,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      ),
                    ),

                    // --- نهاية قسم السعر المحدث ---
                    const Divider(
                      height: 26,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                    ),

                    // ميزات الباقة — تظهر كلّها بلا سقف
                    Column(
                      children: ((plan['features'] as List?) ?? [])
                          .map(
                            (f) => _buildFeatureRow(
                              Icons.check_circle_rounded,
                              f.toString(),
                              isDark,
                              accent,
                            ),
                          )
                          .toList(),
                    ),

                    // يدفع الأزرار لأسفل البطاقة — فتتساوى بصرياً
                    if (stretch) const Spacer(),
                    const SizedBox(height: 20),

                    // مساحة محجوزة — فزرّ الاشتراك في مستوى واحد بكل البطاقات
                    if (planType == 'basic' &&
                        ref.watch(trialEligibleProvider).value == true) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _startingTrial ? null : _startTrial,
                          icon: const Icon(
                            Icons.card_giftcard_rounded,
                            size: 19,
                          ),
                          label: Text(
                            _startingTrial
                                ? 'جاري التفعيل...'
                                : 'ابدأ 3 شهور مجاناً',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brandRed,
                            side: BorderSide(color: brandRed),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox(height: 56),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: isDisabled
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MerchantCheckoutPage(
                                      plan: Map<String, dynamic>.from(plan),
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDisabled
                              ? Colors.grey[300]
                              : brandRed,
                          foregroundColor: isDisabled
                              ? Colors.grey
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _getButtonLabel(status),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الاسم بلا لاحقة المدة — فالتبويبات تبيّنها
  String _planBaseName(String name) {
    var n = name.trim();
    for (final suffix in const [
      'السنوية',
      'الشهرية',
      'سنوية',
      'شهرية',
      'سنوي',
      'شهري',
    ]) {
      if (n.endsWith(' $suffix')) {
        n = n.substring(0, n.length - suffix.length - 1).trim();
        break;
      }
    }
    return n;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "لا توجد باقات متاحة حالياً",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// يضيف فراغاً بين البطاقات داخل الصف
  List<Widget> _spaced(List<Widget> items, double gap, double w) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(Expanded(child: items[i]));
      if (i != items.length - 1) out.add(SizedBox(width: gap));
    }
    return out;
  }

  /// الكروت الثلاثة السفلية
  Widget _sectionTabs() {
    const items = [
      (icon: Icons.autorenew_rounded, label: 'التجديد التلقائي'),
      (icon: Icons.cancel_outlined, label: 'إلغاء الاشتراك'),
      (icon: Icons.receipt_long_outlined, label: 'فواتير المتجر'),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final cols = c.maxWidth >= 620 ? 3 : 1;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(items.length, (i) {
            const on = false;
            final danger = i == 1;

            return SizedBox(
              width: w,
              child: Material(
                color: on ? brandRed : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _sectionPage(i)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on ? brandRed : const Color(0xFFEDEFF3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: on
                                ? Colors.white.withValues(alpha: 0.18)
                                : (danger ? Colors.red : brandRed).withValues(
                                    alpha: 0.08,
                                  ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            items[i].icon,
                            size: 15,
                            color: on
                                ? Colors.white
                                : (danger ? Colors.red : brandRed),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: on ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          on
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: on ? Colors.white70 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// محتوى القسم المفتوح
  /// تُفتح كصفحة مستقلّة عند الضغط على إحدى البطاقات الثلاث
  Widget _sectionPage(int i) {
    switch (i) {
      case 0:
        return const MerchantAutoRenewPage();
      case 1:
        return const MerchantCancelSubscriptionPage();
      case 2:
        return const MerchantInvoicesPage();
      default:
        return const SizedBox.shrink();
    }
  }

  /// مفتاح شهري / سنوي داخل بطاقة الباقة
  Widget _cardBillingToggle(String type, bool isYearly, bool isDark) {
    Widget tab(String label, bool yearly) {
      final on = isYearly == yearly;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _yearlyByType[type] = yearly),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? brandRed : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [tab('شهري', false), tab('سنوي', true)]),
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    String text,
    bool isDark,
    Color brandRed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: brandRed),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
