import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'new_merchants_screen.dart';
import 'admin_reports_screen.dart';

// --- الصفحة الرئيسية: الإحصائيات ---
class AdminMerchantsScreen extends StatefulWidget {
  /// نص البحث — يأتي من الغلاف
  final String searchQuery;

  const AdminMerchantsScreen({super.key, this.searchQuery = ''});

  @override
  State<AdminMerchantsScreen> createState() => _AdminMerchantsScreenState();
}

class _AdminMerchantsScreenState extends State<AdminMerchantsScreen> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFD32027);

  String get _searchQuery => widget.searchQuery;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: supabase
                    .from('profiles')
                    .select()
                    .eq('role', 'merchant')
                    .then((v) => List<Map<String, dynamic>>.from(v)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: brandRed));
                  }
                  final rawData = snapshot.data ?? [];

                  final filteredData = rawData.where((m) {
                    final name = (m['store_name'] ?? m['full_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email = (m['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase()) ||
                        email.contains(_searchQuery.toLowerCase());
                  }).toList();

                  final activeList = filteredData
                      .where((m) =>
                          (m['is_subscription_active'] ?? false) &&
                          !(m['is_banned'] ?? false))
                      .toList();

                  final bannedList = filteredData
                      .where((m) => (m['is_banned'] ?? false))
                      .toList();

                  final expiredList = filteredData
                      .where((m) =>
                          !(m['is_subscription_active'] ?? false) &&
                          !(m['is_banned'] ?? false))
                      .toList();

                  // منطق التجار الذين لم يشتركوا أبداً (بناءً على الجداول المرسلة)
                  final neverSubscribedList = filteredData
                      .where((m) =>
                          !(m['is_subscription_active'] ?? false) &&
                          (m['user_status'] == null ||
                              m['user_status'] == 'new'))
                      .toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildSummaryCard(
                            "إجمالي التجار",
                            "${filteredData.length}",
                            Colors.purple,
                            Icons.group_work,
                            filteredData,
                            "الكل"),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                                child: _buildSmallStatCard(
                                    "نشط حالياً",
                                    "${activeList.length}",
                                    Colors.green,
                                    Icons.bolt,
                                    activeList,
                                    "النشطة")),
                            const SizedBox(width: 15),
                            Expanded(
                                child: _buildSmallStatCard(
                                    "لم يشتركوا أبداً",
                                    "${neverSubscribedList.length}",
                                    Colors.orange,
                                    Icons.person_add_disabled,
                                    neverSubscribedList,
                                    "غير المشتركين")),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                                child: _buildSmallStatCard(
                                    "المحظورة",
                                    "${bannedList.length}",
                                    Colors.black,
                                    Icons.block,
                                    bannedList,
                                    "المحظورة")),
                            const SizedBox(width: 15),
                            Expanded(
                                child: _buildSmallStatCard(
                                    "اشتراك منتهي",
                                    "${expiredList.length}",
                                    Colors.red,
                                    Icons.money_off,
                                    expiredList,
                                    "المنتهية")),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // ===== التجار الجدد — بانتظار التوثيق =====
                        _buildNewMerchantsCard(),

                        const SizedBox(height: 12),

                        // ===== بلاغات المتاجر =====
                        _buildMerchantReportsCard(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة بلاغات المتاجر — تفتح صفحة المراجعة
  Widget _buildMerchantReportsCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('reports')
          .select('id')
          .eq('target_type', 'merchant')
          .eq('status', 'pending')
          .then((v) => List<Map<String, dynamic>>.from(v)),
      builder: (context, snap) {
        final count = (snap.data ?? []).length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportsDetailsPage(
                filterValue: 'merchant',
                title: 'بلاغات المتاجر',
                tableName: 'reports',
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: count > 0
                  ? Colors.red.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: count > 0
                    ? Colors.red.withValues(alpha: 0.35)
                    : const Color(0xFFEDEFF3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.report_problem_outlined,
                      color: Colors.red, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بلاغات المتاجر',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        count > 0
                            ? 'بلاغات قيد المراجعة'
                            : 'لا بلاغات جديدة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left_rounded,
                    color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      },
    );
  }

  /// بطاقة التجار الجدد — تفتح شاشة التوثيق
  Widget _buildNewMerchantsCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('profiles')
          .select('id')
          .eq('role', 'merchant')
          .eq('is_verified', false)
          .then((v) => List<Map<String, dynamic>>.from(v)),
      builder: (context, snap) {
        final count = (snap.data ?? []).length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const NewMerchantsScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: count > 0
                  ? Colors.orange.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: count > 0
                    ? Colors.orange.withValues(alpha: 0.4)
                    : const Color(0xFFEDEFF3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fiber_new_outlined,
                      color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('التجار الجدد',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        count > 0
                            ? 'بانتظار مراجعة وثائقهم'
                            : 'لا طلبات جديدة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left_rounded,
                    color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color,
      IconData icon, List<Map<String, dynamic>> list, String category) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MerchantGridPage(
                  merchants: list, title: category, brandColor: brandRed))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
            ]),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(String title, String value, Color color,
      IconData icon, List<Map<String, dynamic>> list, String category) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MerchantGridPage(
                  merchants: list, title: category, brandColor: brandRed))),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// --- الصفحة الثانية: عرض المربعات (Grid) ---
class MerchantGridPage extends StatefulWidget {
  final List<Map<String, dynamic>> merchants;
  final String title;
  final Color brandColor;
  const MerchantGridPage(
      {super.key,
      required this.merchants,
      required this.title,
      required this.brandColor});

  @override
  State<MerchantGridPage> createState() => _MerchantGridPageState();
}

class _MerchantGridPageState extends State<MerchantGridPage> {
  late List<Map<String, dynamic>> _filteredList;
  String _internalQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredList = widget.merchants;
  }

  void _filter(String val) {
    setState(() {
      _internalQuery = val;
      _filteredList = widget.merchants.where((m) {
        final name =
            (m['store_name'] ?? m['full_name'] ?? '').toString().toLowerCase();
        return name.contains(_internalQuery.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            backgroundColor: widget.brandColor,
            title: Text("متاجر: ${widget.title}",
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white)),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
              decoration: BoxDecoration(
                  color: widget.brandColor,
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30))),
              child: TextField(
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: "بحث في هذه القائمة...",
                  prefixIcon: Icon(Icons.search, color: widget.brandColor),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: _filteredList.isEmpty
                  ? const Center(
                      child: Text("لا توجد بيانات",
                          style: TextStyle(fontFamily: 'Cairo')))
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 0.75),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final m = _filteredList[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      MerchantControlScreen(merchant: m))),
                          child: _buildItem(m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map m) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
              radius: 35,
              backgroundColor: widget.brandColor.withValues(alpha: 0.1),
              backgroundImage: m['store_logo_url'] != null
                  ? NetworkImage(m['store_logo_url'])
                  : null,
              child: m['store_logo_url'] == null
                  ? Icon(Icons.store, color: widget.brandColor, size: 30)
                  : null),
          const SizedBox(height: 12),
          Text(m['store_name'] ?? m['full_name'] ?? 'بدون اسم',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 10),
          _getStatusBadge(m),
        ],
      ),
    );
  }

  Widget _getStatusBadge(Map m) {
    bool isBanned = m['is_banned'] ?? false;
    if (isBanned) {
      return const Text("محظور",
          style: TextStyle(
              color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold));
    }
    bool isSubscriptionActive = m['is_subscription_active'] ?? false;
    return isSubscriptionActive
        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
        : const Text("اشتراك منتهي",
            style: TextStyle(color: Colors.red, fontSize: 10));
  }
}

// --- الصفحة الثالثة: إدارة المتجر ---
class MerchantControlScreen extends StatefulWidget {
  final Map merchant;
  const MerchantControlScreen({super.key, required this.merchant});

  @override
  State<MerchantControlScreen> createState() => _MerchantControlScreenState();
}

class _MerchantControlScreenState extends State<MerchantControlScreen> {
  final supabase = Supabase.instance.client;
  late bool isVerified;
  late bool isBanned;

  String? selectedReason;
  String? selectedDuration;
  bool isPermanentBan = false;

  final List<String> banReasons = [
    "محتوى مخالف للشروط",
    "احتيال أو بلاغات كاذبة",
    "انتهاء فترة السماح للسداد",
    "إساءة استخدام المنصة",
    "أخرى"
  ];

  final List<Map<String, dynamic>> banDurations = [
    {"label": "3 أيام", "days": 3},
    {"label": "أسبوع", "days": 7},
    {"label": "شهر", "days": 30},
  ];

  // ===== الاشتراك =====
  List<Map<String, dynamic>> _plans = [];
  int? _selectedPlanId;
  String? _currentPlanName;
  DateTime? _subEnd;
  bool _subActive = false;
  bool _savingPlan = false;

  @override
  void initState() {
    super.initState();
    isVerified = widget.merchant['is_verified'] ?? false;
    isBanned = widget.merchant['is_banned'] ?? false;
    _loadSubscription();
  }

  /// يجلب الباقات المتاحة واشتراك التاجر الحالي
  Future<void> _loadSubscription() async {
    try {
      final plans = await supabase
          .from('subscription_plans')
          .select('id, name, price, duration_days')
          .eq('is_active', true)
          .order('price');

      final profile = await supabase
          .from('profiles')
          .select(
              'package_name, subscription_end_date, is_subscription_active')
          .eq('id', widget.merchant['id'])
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _plans = List<Map<String, dynamic>>.from(plans);
        _currentPlanName = profile?['package_name']?.toString();
        _subActive = profile?['is_subscription_active'] ?? false;
        final end = profile?['subscription_end_date'];
        _subEnd = end == null ? null : DateTime.tryParse(end.toString());
      });
    } catch (e) {
      debugPrint('Load subscription error: $e');
    }
  }

  /// يُسند الباقة المختارة للتاجر
  Future<void> _assignPlan() async {
    if (_selectedPlanId == null || _savingPlan) return;
    setState(() => _savingPlan = true);

    try {
      await supabase.rpc('assign_plan', params: {
        'p_merchant': widget.merchant['id'],
        'p_plan_id': _selectedPlanId,
      });

      await _loadSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تم إسناد الباقة",
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("تعذر إسناد الباقة: $e",
              style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingPlan = false);
    }
  }

  /// تفعيل أو تعطيل ظهور المتجر للعملاء
  Future<void> _toggleSubscription() async {
    try {
      await supabase.rpc('admin_update_merchant', params: {
        'p_merchant': widget.merchant['id'],
        'p_field': 'is_subscription_active',
        'p_value': !_subActive,
      });
      await _loadSubscription();
    } catch (e) {
      debugPrint('Toggle subscription error: $e');
    }
  }

  Future<void> _toggleStatus(String column, bool currentValue) async {
    final newValue = !currentValue;

    setState(() {
      if (column == 'is_verified') isVerified = newValue;
      if (column == 'is_banned') isBanned = newValue;
    });

    try {
      Map<String, dynamic> updateData = {column: newValue};

      if (column == 'is_banned' && newValue == true) {
        updateData['ban_reason'] = selectedReason ?? "غير محدد";
        updateData['is_permanent_ban'] = isPermanentBan;
        if (!isPermanentBan && selectedDuration != null) {
          int days = banDurations
              .firstWhere((d) => d['label'] == selectedDuration)['days'];
          updateData['ban_until'] =
              DateTime.now().add(Duration(days: days)).toIso8601String();
        }
      }

      // التحديث عبر دالة الأدمن لتجاوز حماية الأعمدة
      for (final entry in updateData.entries) {
        await supabase.rpc('admin_update_merchant', params: {
          'p_merchant': widget.merchant['id'],
          'p_field': entry.key,
          'p_value': entry.value,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تم التحديث", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1)));
    } catch (e) {
      setState(() {
        if (column == 'is_verified') isVerified = currentValue;
        if (column == 'is_banned') isBanned = currentValue;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("فشل الاتصال بالخادم")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFD32027);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text("لوحة التحكم بالمتجر",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.black,
                    fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: Colors.black),
            centerTitle: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                        radius: 60,
                        backgroundColor: brandRed.withValues(alpha: 0.1),
                        backgroundImage: widget.merchant['store_logo_url'] !=
                                null
                            ? NetworkImage(widget.merchant['store_logo_url'])
                            : null,
                        child: widget.merchant['store_logo_url'] == null
                            ? const Icon(Icons.store, size: 60, color: brandRed)
                            : null),
                    const SizedBox(height: 20),
                    Text(widget.merchant['store_name'] ?? 'اسم المتجر',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                    Text(widget.merchant['email'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ===== الاشتراك =====
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_membership_rounded,
                            color: brandRed, size: 20),
                        const SizedBox(width: 8),
                        const Text("الاشتراك",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _subActive
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _subActive ? "ظاهر للعملاء" : "مخفي",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _subActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      _currentPlanName == null
                          ? "لا توجد باقة"
                          : "الباقة الحالية: $_currentPlanName",
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontSize: 13),
                    ),
                    if (_subEnd != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "تنتهي في ${_subEnd!.year}/${_subEnd!.month}/${_subEnd!.day}",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: _subEnd!.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.grey.shade600),
                      ),
                    ],

                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedPlanId,
                      isExpanded: true,
                      style: const TextStyle(
                          fontFamily: 'Cairo', color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        hintText: "اختر باقة",
                        hintStyle: const TextStyle(fontFamily: 'Cairo'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: _plans
                          .map((p) => DropdownMenuItem<int>(
                                value: (p['id'] as num).toInt(),
                                child: Text(
                                  "${p['name']} — ${p['price']} ر.س / ${p['duration_days']} يوم",
                                  style: const TextStyle(
                                      fontFamily: 'Cairo', fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPlanId = v),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _savingPlan ? null : _assignPlan,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                                _savingPlan ? "جاري الحفظ..." : "إسناد الباقة",
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _toggleSubscription,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(_subActive ? "إخفاء" : "إظهار",
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildAdminButton(
                label: isVerified ? "تعطيل حساب المتجر" : "تفعيل المتجر الآن",
                icon: isVerified
                    ? Icons.no_accounts_rounded
                    : Icons.verified_rounded,
                primaryColor:
                    isVerified ? Colors.orange.shade600 : Colors.green.shade600,
                onTap: () => _toggleStatus('is_verified', isVerified),
              ),
              const SizedBox(height: 20),
              if (!isBanned) ...[
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text("إعدادات الحظر:",
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    hintText: "اختر سبب الحظر",
                  ),
                  items: banReasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedReason = val),
                ),
                const SizedBox(height: 10),
                if (!isPermanentBan)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                      hintText: "حدد مدة الحظر",
                    ),
                    items: banDurations
                        .map((d) => DropdownMenuItem(
                            value: d['label'] as String,
                            child: Text(d['label'])))
                        .toList(),
                    onChanged: (val) => setState(() => selectedDuration = val),
                  ),
                CheckboxListTile(
                  title: const Text("حظر دائم (لا يمكن للمتجر التظلم)",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  value: isPermanentBan,
                  onChanged: (val) => setState(() {
                    isPermanentBan = val!;
                    if (isPermanentBan) selectedDuration = null;
                  }),
                  activeColor: brandRed,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              _buildAdminButton(
                label: isBanned ? "رفع الحظر عن المتجر" : "تأكيد حظر المتجر",
                icon: isBanned ? Icons.gavel_rounded : Icons.block_flipped,
                primaryColor: isBanned ? Colors.blueGrey.shade700 : brandRed,
                onTap: () {
                  if (!isBanned) {
                    if (selectedReason == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("يرجى اختيار سبب الحظر")));
                      return;
                    }
                    if (!isPermanentBan && selectedDuration == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("يرجى اختيار مدة الحظر")));
                      return;
                    }
                  }
                  _toggleStatus('is_banned', isBanned);
                },
              ),
              const SizedBox(height: 20),
              _buildAdminButton(
                label: "إرسال رسالة إدارية",
                icon: Icons.chat_bubble_outline_rounded,
                primaryColor: Colors.blue.shade800,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildAdminButton(
                label: "إحصائيات المتجر",
                icon: Icons.dashboard_customize_rounded,
                primaryColor: Colors.teal.shade700,
                onTap: _showMerchantStats,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// يعرض إحصائيات المتجر المحدد (عروض · ريلز · زيارات)
  Future<void> _showMerchantStats() async {
    final id = widget.merchant['id']?.toString();
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final products =
          await supabase.from('products').select('id').eq('merchant_id', id);
      final reels =
          await supabase.from('reels').select('id').eq('merchant_id', id);
      final visits = await supabase
          .from('analytics_visits')
          .select('id')
          .eq('merchant_id', id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إحصائيات المتجر',
                style: TextStyle(fontFamily: 'Cairo')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statRow('العروض', (products as List).length),
                _statRow('الريلز', (reels as List).length),
                _statRow('الزيارات', (visits as List).length),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              )
            ],
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذر جلب الإحصائيات: $e')));
    }
  }

  Widget _statRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Cairo')),
            Text('$value',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32027))),
          ],
        ),
      );

  Widget _buildAdminButton(
      {required String label,
      required IconData icon,
      required Color primaryColor,
      required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
