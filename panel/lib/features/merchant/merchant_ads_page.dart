import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'banner_terms_sheet.dart';
import 'merchant_nav.dart';

/// شاشة بنرات التاجر — شراء المساحات الإعلانية الأسبوعية
class MerchantAdsPage extends StatefulWidget {
  const MerchantAdsPage({super.key});

  @override
  State<MerchantAdsPage> createState() => _MerchantAdsPageState();
}

class _MerchantAdsPageState extends State<MerchantAdsPage> {
  static const Color brandRed = Color(0xFFD32027);

  // مقاسات ملزمة
  static const Map<String, ({int w, int h})> _sizes = {
    'wide': (w: 1500, h: 350),
    'small': (w: 760, h: 400),
  };
  static const int _maxKb = 500;

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _weeks = [];
  List<Map<String, dynamic>> _myBookings = [];
  bool _loading = true;
  int _tab = 0;

  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

  // ===== إعلان الشاشة الرئيسية =====
  List<Map<String, dynamic>> _splashDays = [];
  List<Map<String, dynamic>> _mySplashAds = [];
  bool _loadingSplash = true;
  String _splashSub = 'calendar';
  String _splashFilter = 'active';
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _adsFilter = 'active';

  @override
  void initState() {
    super.initState();
    _load();
    _loadStats();
    _loadSplash();
  }

  /// يجلب تقويم الأيام وإعلانات التاجر
  Future<void> _loadSplash() async {
    try {
      final uid = supabase.auth.currentUser?.id;

      final days = await supabase.rpc('get_splash_days');

      List ads = [];
      if (uid != null) {
        ads = await supabase
            .from('splash_ads')
            .select()
            .eq('merchant_id', uid)
            .order('ad_date', ascending: false);
      }

      if (!mounted) return;
      setState(() {
        _splashDays = List<Map<String, dynamic>>.from(days as List);
        _mySplashAds = List<Map<String, dynamic>>.from(ads);
        _loadingSplash = false;
      });
    } catch (e) {
      debugPrint('Splash load error: $e');
      if (mounted) setState(() => _loadingSplash = false);
    }
  }

  /// يجلب إحصاءات أداء البنرات
  Future<void> _loadStats() async {
    try {
      final res = await supabase.rpc('get_merchant_banner_stats');
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(res as Map);
        _loadingStats = false;
      });
    } catch (e) {
      debugPrint('Stats error: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final weeks = await supabase.rpc('get_available_weeks');

      final uid = supabase.auth.currentUser?.id;
      List bookings = [];
      if (uid != null) {
        bookings = await supabase
            .from('banner_bookings')
            .select(
                '*, banner_weeks(week_number, year, week_start, week_end)')
            .eq('merchant_id', uid)
            .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          _weeks = List<Map<String, dynamic>>.from(weeks as List);
          _myBookings = List<Map<String, dynamic>>.from(bookings);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Ads load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _fmt(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '—';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('بنراتي',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'اشترِ مساحة إعلانية أسبوعية تظهر لزوار المنصة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 18),

                  // ===== التبويبات =====
                  Wrap(
                    spacing: 8,
                    children: [
                      _tabChip(0, 'الأسابيع المتاحة', _weeks.length),
                      _tabChip(1, 'بنراتي', _myBookings.length),
                      _tabChip(3, 'إعلان الشاشة الرئيسية', null),
                      _tabChip(2, 'الأداء', null),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_tab == 0)
                    _weeksGrid()
                  else if (_tab == 1)
                    _bookingsList()
                  else if (_tab == 3)
                    _splashView()
                  else
                    _statsView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabChip(int index, String label, int? count) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? brandRed : const Color(0xFFEDEFF3)),
        ),
        child: Text(
          count == null ? label : '$label ($count)',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
            color: on ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ===================== الأسابيع =====================

  Widget _weeksGrid() {
    if (_weeks.isEmpty) {
      return _empty('لا توجد أسابيع متاحة للحجز حالياً',
          Icons.calendar_month_outlined);
    }

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        int cols = 4;
        if (c.maxWidth < 560) {
          cols = 1;
        } else if (c.maxWidth < 820) {
          cols = 2;
        } else if (c.maxWidth < 1080) {
          cols = 3;
        }
        final w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: _weeks
              .map((week) => SizedBox(width: w, child: _weekCard(week)))
              .toList(),
        );
      },
    );
  }

  Widget _weekCard(Map<String, dynamic> w) {
    final occasion = (w['occasion_name'] ?? '').toString();
    final wideLeft = (w['wide_available'] as num?)?.toInt() ?? 0;
    final smallLeft = (w['small_available'] as num?)?.toInt() ?? 0;

    final isOpen = w['is_open'] == true;
    final isPast = w['is_past'] == true;
    final soldOut = wideLeft <= 0 && smallLeft <= 0;

    // مغلق لأي سبب: الأدمن أغلقه · أو فات وقته · أو اكتمل
    final closed = !isOpen || isPast || soldOut;

    const String closedReason = 'اكتمل الحجز';

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFF4F5F7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: closed
              ? const Color(0xFFE5E7EB)
              : occasion.isNotEmpty
                  ? brandRed.withValues(alpha: 0.35)
                  : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: closed
                      ? Colors.grey.withValues(alpha: 0.12)
                      : brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'أسبوع ${w['week_number']} · ${w['year']}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: closed ? Colors.grey : brandRed,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            '${_fmt(w['week_start'])} — ${_fmt(w['week_end'])}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: closed ? Colors.grey : const Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            occasion.isEmpty ? 'أسبوع عادي' : occasion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight:
                  occasion.isEmpty ? FontWeight.normal : FontWeight.bold,
              color: closed
                  ? Colors.grey.shade400
                  : occasion.isEmpty
                      ? Colors.grey.shade400
                      : brandRed,
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 12),

          _typeRow(w, 'wide', 'عريض', w['price_wide'], wideLeft, closed),
          const SizedBox(height: 8),
          _typeRow(w, 'small', 'صغير', w['price_small'], smallLeft, closed),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                closed
                    ? Icons.lock_outline_rounded
                    : Icons.shopping_cart_outlined,
                size: 14,
                color: closed ? Colors.grey : Colors.green,
              ),
              const SizedBox(width: 7),
              Text(
                closed ? closedReason : 'متاح للشراء',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: closed ? Colors.grey : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!closed) return card;

    // ===== ختم "مغلق" بالعرض =====
    return Stack(
      children: [
        Opacity(opacity: 0.55, child: card),
        Positioned.fill(
          child: Center(
            child: Transform.rotate(
              angle: -0.14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.7), width: 2),
                ),
                child: const Text(
                  closedReason,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeRow(Map<String, dynamic> w, String type, String label,
      dynamic price, int left, bool weekClosed) {
    final gone = weekClosed || left <= 0;
    final scarce = !gone && left <= 3;

    return InkWell(
      onTap: gone ? null : () => _openBooking(w, type),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: Colors.grey.shade600)),
          ),
          Text(
            '${(price as num?)?.toInt() ?? 0}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: gone ? Colors.grey : const Color(0xFF1F2937),
            ),
          ),
          Text(' ر.س',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.grey.shade500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: gone
                  ? Colors.grey.withValues(alpha: 0.1)
                  : scarce
                      ? Colors.orange.withValues(alpha: 0.13)
                      : const Color(0xFFF1F2F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              left <= 0 ? 'مكتمل' : 'باقٍ $left',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: gone
                    ? Colors.grey
                    : scarce
                        ? Colors.orange.shade800
                        : Colors.grey.shade600,
              ),
            ),
          ),
          if (!gone) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_left_rounded,
                size: 17, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
  }

  // ===================== نافذة الحجز =====================

  void _openBooking(Map<String, dynamic> week, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        week: week,
        bannerType: type,
        onDone: _load,
      ),
    );
  }

  // ===================== بنراتي =====================

  /// يصنّف البنر — والموقوف في خانة "إجراء"
  String _groupOf(String status) {
    if (status == 'suspended') return 'action';
    if (status == 'cancelled' || status == 'banned') return 'cancelled';
    if (status == 'expired') return 'expired';
    return 'active'; // paid · scheduled · active
  }

  Widget _bookingsList() {
    final actionCount = _myBookings
        .where((b) => _groupOf((b['status'] ?? '').toString()) == 'action')
        .length;

    // خانة "إجراء" تظهر عند الحاجة فقط
    final filters = <({String key, String label})>[
      if (actionCount > 0) (key: 'action', label: 'إجراء'),
      (key: 'active', label: 'فعّال'),
      (key: 'expired', label: 'منتهي'),
      (key: 'cancelled', label: 'ملغى'),
    ];

    if (_adsFilter == 'action' && actionCount == 0) {
      _adsFilter = 'active';
    }

    final filtered = _myBookings
        .where((b) =>
            _groupOf((b['status'] ?? '').toString()) == _adsFilter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((f) {
            final count = _myBookings
                .where((b) =>
                    _groupOf((b['status'] ?? '').toString()) == f.key)
                .length;
            final on = _adsFilter == f.key;
            final urgent = f.key == 'action';

            return GestureDetector(
              onTap: () => setState(() => _adsFilter = f.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: on
                      ? (urgent
                          ? Colors.orange.withValues(alpha: 0.12)
                          : brandRed.withValues(alpha: 0.08))
                      : (urgent
                          ? Colors.orange.withValues(alpha: 0.06)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: urgent
                        ? Colors.orange
                        : (on ? brandRed : const Color(0xFFEDEFF3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (urgent) ...[
                      const Icon(Icons.priority_high_rounded,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${f.label} ($count)',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: (on || urgent)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: urgent
                            ? Colors.orange.shade800
                            : (on ? brandRed : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        if (filtered.isEmpty)
          _empty(
            _adsFilter == 'active'
                ? 'لا بنرات فعّالة'
                : _adsFilter == 'expired'
                    ? 'لا بنرات منتهية'
                    : 'لا بنرات ملغاة',
            Icons.ad_units_outlined,
          )
        else
          ...filtered.map(_bookingCard),
      ],
    );
  }

  /// تعديل بنر — الصورة والوجهة
  void _editBooking(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdEditSheet(
        kind: 'banner',
        id: b['id'].toString(),
        currentTarget: (b['target_type'] ?? 'store').toString(),
        currentProduct: b['product_id']?.toString(),
        width: b['banner_type'] == 'wide' ? 1500 : 760,
        height: b['banner_type'] == 'wide' ? 350 : 400,
        maxKb: 500,
        onDone: _load,
      ),
    );
  }

  /// إلغاء بنر مدفوع
  Future<void> _cancelBooking(Map<String, dynamic> b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إلغاء البنر',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          content: Text(
            'سيُلغى البنر ويعود المبلغ '
            '${(b['final_price'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س '
            'إلى رصيدك.',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await supabase.rpc('cancel_banner_purchase',
          params: {'p_booking_id': b['id']});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack(
          'أُلغي البنر — أُعيد '
          '${(map['refunded'] as num?)?.toStringAsFixed(2)} ر.س لرصيدك',
          Colors.green,
        );
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الإلغاء', Colors.red);
      }
    } catch (e) {
      debugPrint('Cancel error: $e');
      _snack('تعذر تنفيذ الإلغاء', Colors.red);
    }
  }

  /// هل ما زال الإلغاء متاحاً؟
  bool _canCancel(Map<String, dynamic> b) {
    final status = (b['status'] ?? '').toString();
    if (status != 'paid' && status != 'scheduled') return false;

    final week = b['banner_weeks'] as Map<String, dynamic>?;
    final start = DateTime.tryParse((week?['week_start'] ?? '').toString());
    if (start == null) return false;

    return start.difference(DateTime.now()).inHours >= 24;
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final week = b['banner_weeks'] as Map<String, dynamic>?;
    final status = (b['status'] ?? '').toString();

    final (String label, Color color) = switch (status) {
      'paid' => ('مدفوع — لم يبدأ', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض الآن', Colors.green),
      'suspended' => ('موقوف — بانتظار تعديلك', Colors.orange),
      'banned' => ('محظور', Color(0xFFB71C1C)),
      'expired' => ('انتهى', Colors.grey),
      'cancelled' => ('ملغى', Colors.grey),
      _ => (status, Colors.grey),
    };

    final showStats = status == 'active' || status == 'expired';

    // التعديل متاح ما بقي أكثر من 24 ساعة
    final start = DateTime.tryParse((week?['week_start'] ?? '').toString());
    final canEdit = ['paid', 'scheduled', 'active', 'suspended']
            .contains(status) &&
        start != null &&
        start.difference(DateTime.now()).inHours >= 24;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'active'
              ? Colors.green.withValues(alpha: 0.3)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if ((b['image_url'] ?? '').toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    b['image_url'],
                    width: 74,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 74,
                      height: 40,
                      color: const Color(0xFFF1F2F5),
                      child: const Icon(Icons.image_outlined,
                          size: 17, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['banner_type'] == 'wide' ? 'بنر عريض' : 'بنر صغير',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold),
                    ),
                    if (week != null)
                      Text(
                        '${_fmt(week['week_start'])} — ${_fmt(week['week_end'])}',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Text('${b['slots_count']} بنر',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600)),
              const Spacer(),
              Text(
                '${(b['final_price'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: status == 'cancelled' ? Colors.grey : brandRed,
                    decoration: status == 'cancelled'
                        ? TextDecoration.lineThrough
                        : null),
              ),
            ],
          ),

          // ===== سبب الإيقاف من الإدارة =====
          if ((b['rejection_reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  right: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5), width: 2.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 7),
                      const Text('سبب الإيقاف',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b['rejection_reason'].toString(),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        height: 1.8,
                        color: Colors.red),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أُعيد المبلغ إلى رصيد متجرك',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],

          if (showStats) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('${b['impressions'] ?? 0} ظهور',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.touch_app_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('${b['clicks'] ?? 0} نقرة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
              ],
            ),
          ],

          if (canEdit || _canCancel(b)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canEdit)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => _editBooking(b),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(
                            status == 'suspended'
                                ? 'تعديل وإعادة للمراجعة'
                                : 'تعديل البنر',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == 'suspended'
                              ? Colors.orange
                              : brandRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                if (canEdit && _canCancel(b)) const SizedBox(width: 10),
                if (_canCancel(b))
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelBooking(b),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('إلغاء',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===================== الأداء =====================

  Widget _statsView() {
    if (_loadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    final st = _stats;
    if (st == null || st['ok'] != true) {
      return _empty('تعذر تحميل الأداء', Icons.bar_chart_outlined);
    }

    final impressions = (st['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (st['clicks'] as num?)?.toInt() ?? 0;
    final ctr = (st['ctr'] as num?)?.toDouble() ?? 0;
    final platformCtr = (st['platform_ctr'] as num?)?.toDouble() ?? 0;
    final banners = (st['total_banners'] as num?)?.toInt() ?? 0;
    final spent = (st['total_spent'] as num?)?.toDouble() ?? 0;
    final best = st['best'] as Map<String, dynamic>?;

    if (impressions == 0 && banners == 0) {
      return _empty(
          'لا بيانات بعد — تظهر بعد عرض أول بنر', Icons.bar_chart_outlined);
    }

    final better = ctr >= platformCtr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== البطاقات =====
        LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            final cols = c.maxWidth < 560 ? 2 : 4;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                    width: w,
                    child: _statCard('الظهور', '$impressions',
                        Icons.visibility_outlined, Colors.blue)),
                SizedBox(
                    width: w,
                    child: _statCard('النقرات', '$clicks',
                        Icons.touch_app_outlined, Colors.orange)),
                SizedBox(
                    width: w,
                    child: _statCard('معدل النقر', '$ctr%',
                        Icons.percent_rounded,
                        better ? Colors.green : Colors.grey)),
                SizedBox(
                    width: w,
                    child: _statCard('بنراتك', '$banners',
                        Icons.ad_units_outlined, brandRed)),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ===== المقارنة =====
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (better ? Colors.green : Colors.orange)
                .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (better ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                better
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: better ? Colors.green : Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      better
                          ? 'أداؤك أعلى من متوسط المنصة'
                          : 'أداؤك دون متوسط المنصة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: better ? Colors.green.shade800
                                      : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'معدل نقرك $ctr% · ومتوسط المنصة $platformCtr%',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ===== أفضل بنر =====
        if (best != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        size: 18, color: brandRed),
                    const SizedBox(width: 10),
                    const Text('أفضل بنر لك',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${best['banner_type'] == 'wide' ? 'عريض' : 'صغير'} · '
                      'أسبوع ${best['week_number']}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: Colors.grey.shade700),
                    ),
                    const Spacer(),
                    Text(
                      '${best['ctr']}%',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${best['impressions']} ظهور · ${best['clicks']} نقرة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // ===== الإنفاق =====
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.payments_outlined,
                  size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text('إجمالي إنفاقك على البنرات',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      color: Colors.grey.shade700)),
              const Spacer(),
              Text(
                '${spent.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 11),
          Text(
            value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ===================== إعلان الشاشة الرئيسية =====================

  static const _splashSubs = [
    (key: 'calendar', label: 'التقويم'),
    (key: 'mine', label: 'إعلاناتي'),
  ];

  Widget _splashView() {
    if (_loadingSplash) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== الأزرار الداخلية =====
        Wrap(
          spacing: 8,
          children: _splashSubs.map((f) {
            final on = _splashSub == f.key;
            return GestureDetector(
              onTap: () => setState(() => _splashSub = f.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? brandRed.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: on ? brandRed : const Color(0xFFEDEFF3)),
                ),
                child: Text(
                  f.key == 'mine'
                      ? '${f.label} (${_mySplashAds.length})'
                      : f.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: on ? FontWeight.bold : FontWeight.normal,
                    color: on ? brandRed : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        if (_splashSub == 'calendar') _calendarView() else _mySplashList(),
      ],
    );
  }

  // ===== التقويم الشهري =====

  Widget _calendarView() {
    const names = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    // أيام الشهر المعروض
    final first = DateTime(_calMonth.year, _calMonth.month, 1);
    final daysInMonth =
        DateTime(_calMonth.year, _calMonth.month + 1, 0).day;

    // الأحد أول الأسبوع: weekday الأحد = 7
    final lead = first.weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== شريط الشهر =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _calMonth =
                      DateTime(_calMonth.year, _calMonth.month - 1);
                }),
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                color: Colors.grey.shade700,
              ),
              Expanded(
                child: Text(
                  '${names[_calMonth.month - 1]} ${_calMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _calMonth =
                      DateTime(_calMonth.year, _calMonth.month + 1);
                }),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ===== رؤوس الأيام =====
        Row(
          children: const ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8A93A6))),
                    ),
                  ))
              .toList(),
        ),

        const SizedBox(height: 10),

        // ===== الشبكة =====
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
          ),
          itemCount: lead + daysInMonth,
          itemBuilder: (context, i) {
            if (i < lead) return const SizedBox.shrink();

            final day = DateTime(_calMonth.year, _calMonth.month, i - lead + 1);
            return _dayCell(day);
          },
        ),

        const SizedBox(height: 16),

        // ===== المفتاح =====
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _legend('متاح', Colors.white, const Color(0xFFD5D8DE)),
            _legend('محجوز', brandRed.withValues(alpha: 0.1), brandRed),
            _legend('مغلق', const Color(0xFFF1F2F5), const Color(0xFFE5E7EB)),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          'الحجز متاح بعد ثلاثة أيام من اليوم — لإتاحة وقت المراجعة',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _legend(String label, Color fill, Color border) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade600)),
      ],
    );
  }

  /// خانة يوم واحد
  Widget _dayCell(DateTime day) {
    final key = _dateKey(day);

    final info = _splashDays.cast<Map<String, dynamic>?>().firstWhere(
          (d) => (d?['ad_date'] ?? '').toString().startsWith(key),
          orElse: () => null,
        );

    // خارج نطاق الأيام المولّدة
    if (info == null) {
      return _cellBox(
        day.day,
        fill: const Color(0xFFFAFAFA),
        border: const Color(0xFFF1F2F5),
        textColor: Colors.grey.shade300,
      );
    }

    final taken = info['is_taken'] == true;
    final past = info['is_past'] == true;
    final open = info['is_open'] == true;
    final price = (info['price'] as num?)?.toInt() ?? 0;
    final occasion = (info['occasion_name'] ?? '').toString();

    // محجوز
    if (taken) {
      return _cellBox(
        day.day,
        fill: brandRed.withValues(alpha: 0.1),
        border: brandRed.withValues(alpha: 0.5),
        textColor: brandRed,
        label: 'محجوز',
      );
    }

    // مغلق أو فات وقته
    if (past || !open) {
      return _cellBox(
        day.day,
        fill: const Color(0xFFF1F2F5),
        border: const Color(0xFFE5E7EB),
        textColor: Colors.grey.shade400,
      );
    }

    // متاح
    return InkWell(
      onTap: () => _openSplashBooking(day, price, occasion),
      borderRadius: BorderRadius.circular(9),
      child: _cellBox(
        day.day,
        fill: Colors.white,
        border: occasion.isNotEmpty
            ? brandRed.withValues(alpha: 0.4)
            : const Color(0xFFD5D8DE),
        textColor: const Color(0xFF1F2937),
        label: '$price',
      ),
    );
  }

  Widget _cellBox(
    int day, {
    required Color fill,
    required Color border,
    required Color textColor,
    String? label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 8.5, color: textColor),
            ),
          ],
        ],
      ),
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _openSplashBooking(DateTime day, int price, String occasion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SplashBookingSheet(
        adDate: _dateKey(day),
        price: price,
        occasion: occasion,
        onDone: _loadSplash,
      ),
    );
  }

  // ===== إعلاناتي =====

  /// تصنيف الإعلان
  String _splashGroupOf(String status) {
    if (status == 'suspended') return 'action';
    if (status == 'cancelled' || status == 'banned') return 'cancelled';
    if (status == 'expired') return 'expired';
    return 'active'; // paid · scheduled · active
  }

  Widget _mySplashList() {
    if (_mySplashAds.isEmpty) {
      return _empty('لم تشترِ أي إعلان بعد', Icons.smartphone_outlined);
    }

    final actionCount = _mySplashAds
        .where((a) =>
            _splashGroupOf((a['status'] ?? '').toString()) == 'action')
        .length;

    // خانة "إجراء" تظهر عند الحاجة فقط
    final filters = <({String key, String label})>[
      if (actionCount > 0) (key: 'action', label: 'إجراء'),
      (key: 'active', label: 'فعّال'),
      (key: 'expired', label: 'منتهي'),
      (key: 'cancelled', label: 'ملغى'),
    ];

    // إن اختفت الخانة نعود للفعّال
    if (_splashFilter == 'action' && actionCount == 0) {
      _splashFilter = 'active';
    }

    final filtered = _mySplashAds
        .where((a) =>
            _splashGroupOf((a['status'] ?? '').toString()) == _splashFilter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((f) {
            final count = _mySplashAds
                .where((a) =>
                    _splashGroupOf((a['status'] ?? '').toString()) == f.key)
                .length;
            final on = _splashFilter == f.key;
            final urgent = f.key == 'action';

            return GestureDetector(
              onTap: () => setState(() => _splashFilter = f.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: on
                      ? (urgent
                          ? Colors.orange.withValues(alpha: 0.12)
                          : brandRed.withValues(alpha: 0.08))
                      : (urgent
                          ? Colors.orange.withValues(alpha: 0.06)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: urgent
                        ? Colors.orange
                        : (on ? brandRed : const Color(0xFFEDEFF3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (urgent) ...[
                      const Icon(Icons.priority_high_rounded,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${f.label} ($count)',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: (on || urgent)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: urgent
                            ? Colors.orange.shade800
                            : (on ? brandRed : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        if (filtered.isEmpty)
          _empty(
            _splashFilter == 'active'
                ? 'لا إعلانات فعّالة'
                : _splashFilter == 'expired'
                    ? 'لا إعلانات منتهية'
                    : 'لا إعلانات ملغاة',
            Icons.smartphone_outlined,
          )
        else
          ...filtered.map(_splashCard),
      ],
    );
  }

  /// تعديل إعلان — الصورة والوجهة
  void _editSplashAd(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdEditSheet(
        kind: 'splash',
        id: a['id'].toString(),
        currentTarget: (a['target_type'] ?? 'store').toString(),
        currentProduct: a['product_id']?.toString(),
        width: 1080,
        height: 1920,
        maxKb: 300,
        onDone: _loadSplash,
      ),
    );
  }

  Widget _splashCard(Map<String, dynamic> a) {
    final status = (a['status'] ?? '').toString();
    final reason = (a['rejection_reason'] ?? '').toString();

    final (String label, Color color) = switch (status) {
      'paid' => ('مدفوع', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض اليوم', Colors.green),
      'suspended' => ('موقوف — بانتظار تعديلك', Colors.orange),
      'banned' => ('محظور', Color(0xFFB71C1C)),
      'expired' => ('انتهى', Colors.grey),
      'cancelled' => ('ملغى', Colors.grey),
      _ => (status, Colors.grey),
    };

    final adDate = (a['ad_date'] ?? '').toString();
    final hoursLeft = DateTime.tryParse(adDate)
            ?.difference(DateTime.now())
            .inHours ??
        0;

    final canCancel =
        (status == 'paid' || status == 'scheduled') && hoursLeft >= 24;

    final canEdit = ['paid', 'scheduled', 'active', 'suspended']
            .contains(status) &&
        hoursLeft >= 24;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'active'
              ? Colors.green.withValues(alpha: 0.3)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if ((a['image_url'] ?? '').toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    a['image_url'],
                    width: 40,
                    height: 66,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 66,
                      color: const Color(0xFFF1F2F5),
                      child: const Icon(Icons.image_outlined,
                          size: 15, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إعلان الشاشة الرئيسية',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      adDate,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${a['impressions'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const SizedBox(width: 14),
              Icon(Icons.skip_next_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${a['skips'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const SizedBox(width: 14),
              Icon(Icons.touch_app_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${a['clicks'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const Spacer(),
              Text(
                '${(a['final_price'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: status == 'cancelled' || status == 'suspended'
                        ? Colors.grey
                        : brandRed,
                    decoration:
                        status == 'cancelled' || status == 'suspended'
                            ? TextDecoration.lineThrough
                            : null),
              ),
            ],
          ),

          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  right: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5), width: 2.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('سبب الإيقاف',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  const SizedBox(height: 6),
                  Text(reason,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          height: 1.8,
                          color: Colors.red)),
                ],
              ),
            ),
          ],

          if (canEdit || canCancel) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canEdit)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => _editSplashAd(a),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(
                            status == 'suspended'
                                ? 'تعديل وإعادة للمراجعة'
                                : 'تعديل الإعلان',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == 'suspended'
                              ? Colors.orange
                              : brandRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                if (canEdit && canCancel) const SizedBox(width: 10),
                if (canCancel)
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelSplashAd(a),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('إلغاء',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancelSplashAd(Map<String, dynamic> a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إلغاء الإعلان',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          content: Text(
            'سيُلغى الإعلان ويعود المبلغ '
            '${(a['final_price'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س '
            'إلى رصيدك.',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await supabase
          .rpc('cancel_splash_ad', params: {'p_ad_id': a['id']});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _loadSplash();
        _snack(
          'أُلغي الإعلان — أُعيد '
          '${(map['refunded'] as num?)?.toStringAsFixed(2)} ر.س لرصيدك',
          Colors.green,
        );
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الإلغاء', Colors.red);
      }
    } catch (e) {
      debugPrint('Cancel splash error: $e');
      _snack('تعذر تنفيذ الإلغاء', Colors.red);
    }
  }

  Widget _empty(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(msg,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ============================================================
//                      نافذة الحجز
// ============================================================

class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> week;
  final String bannerType;
  final VoidCallback onDone;

  const _BookingSheet({
    required this.week,
    required this.bannerType,
    required this.onDone,
  });

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  static const Color brandRed = Color(0xFFD32027);
  static const int _maxKb = 500;

  final supabase = Supabase.instance.client;
  final _promoCtrl = TextEditingController();

  int _slots = 1;
  String _targetType = 'store';
  String? _productId;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedUrl;
  bool _termsAccepted = false;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> _products = [];
  double _balance = 0;
  bool _loadingBalance = true;

  ({int w, int h}) get _size => widget.bannerType == 'wide'
      ? (w: 1500, h: 350)
      : (w: 760, h: 400);

  int get _unitPrice => widget.bannerType == 'wide'
      ? (widget.week['price_wide'] as num?)?.toInt() ?? 0
      : (widget.week['price_small'] as num?)?.toInt() ?? 0;

  int get _available => widget.bannerType == 'wide'
      ? (widget.week['wide_available'] as num?)?.toInt() ?? 0
      : (widget.week['small_available'] as num?)?.toInt() ?? 0;

  int get _maxSlots {
    final cap = (widget.week['max_slots'] as num?)?.toInt() ?? 4;
    return cap < _available ? cap : _available;
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadBalance();
  }

  /// يجلب رصيد المتجر
  Future<void> _loadBalance() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final res = await supabase
          .from('merchant_wallets')
          .select('balance')
          .eq('merchant_id', uid)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _balance = ((res?['balance'] as num?) ?? 0).toDouble();
        _loadingBalance = false;
      });
    } catch (e) {
      debugPrint('Balance error: $e');
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final res = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', uid)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => _products = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('Products load error: $e');
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// اختيار الصورة مع فحص فوري
  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // الحجم
      final kb = bytes.lengthInBytes / 1024;
      if (kb > _maxKb) {
        setState(() => _error =
            'حجم الملف ${kb.toStringAsFixed(0)} كيلوبايت — '
            'والحد الأقصى $_maxKb\n'
            'جرّب حفظ الصورة بصيغة JPG لتقليل حجمها');
        return;
      }

      // المقاس
      final decoded = await decodeImageFromList(bytes);
      if (decoded.width != _size.w || decoded.height != _size.h) {
        setState(() => _error =
            'المقاس غير مطابق\nالصورة: ${decoded.width} × ${decoded.height}\n'
            'المطلوب: ${_size.w} × ${_size.h}');
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _uploadedUrl = null;
        _error = null;
      });
    } catch (e) {
      debugPrint('Pick error: $e');
      setState(() => _error = 'تعذر قراءة الصورة');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return null;
    if (_uploadedUrl != null) return _uploadedUrl;

    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = (_imageName ?? 'banner.png').split('.').last;
      final path =
          'bookings/$uid-${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('banners_bucket').uploadBinary(
            path,
            _imageBytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      _uploadedUrl =
          supabase.storage.from('banners_bucket').getPublicUrl(path);
      return _uploadedUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_imageBytes == null) {
      setState(() => _error = 'ارفع صورة البنر أولاً');
      return;
    }
    if (_targetType == 'product' && _productId == null) {
      setState(() => _error = 'اختر العرض المستهدف');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'يجب الموافقة على شروط الإعلان');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final url = await _uploadImage();
      if (url == null) {
        setState(() {
          _error = 'تعذر رفع الصورة';
          _busy = false;
        });
        return;
      }

      final res = await supabase.rpc('purchase_banner', params: {
        'p_week_id': widget.week['id'],
        'p_banner_type': widget.bannerType,
        'p_slots': _slots,
        'p_image_url': url,
        'p_target_type': _targetType,
        'p_product_id': _productId,
        'p_promo_code':
            _promoCtrl.text.trim().isEmpty ? null : _promoCtrl.text.trim(),
        'p_terms_version': 'v1.0',
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onDone();
        _snack(
          'تم الشراء — رصيدك المتبقي '
          '${(map['balance'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س',
          Colors.green,
        );
      } else {
        setState(() {
          _error = map['error']?.toString() ?? 'تعذر إتمام الشراء';
          _busy = false;
        });
      }
    } catch (e) {
      debugPrint('Book error: $e');
      setState(() {
        _error = 'تعذر إتمام الشراء، حاول مجدداً';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _unitPrice * _slots;
    final vat = subtotal * 0.15;
    final total = subtotal + vat;
    final enough = _loadingBalance || _balance >= total;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== المقبض =====
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.bannerType == 'wide'
                              ? 'حجز بنر عريض'
                              : 'حجز بنر صغير',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المقاس ${_size.w} × ${_size.h} بكسل · '
                          'الحد الأقصى $_maxKb كيلوبايت · JPG أو WebP',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),

                        const SizedBox(height: 20),

                        // ===== الصورة =====
                        _sectionTitle('صورة البنر', Icons.image_outlined),
                        const SizedBox(height: 10),

                        if (_imageBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.memory(
                              _imageBytes!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        InkWell(
                          onTap: _busy ? null : _pickImage,
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: _imageBytes != null
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: _imageBytes != null
                                    ? Colors.green.withValues(alpha: 0.35)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _imageBytes != null
                                      ? Icons.check_circle_rounded
                                      : Icons.upload_file_rounded,
                                  size: 19,
                                  color: _imageBytes != null
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _imageBytes != null
                                        ? 'الصورة مطابقة للمواصفات'
                                        : 'اختر صورة البنر',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: _imageBytes != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _imageBytes != null
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (_imageBytes != null)
                                  Text('تغيير',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11.5,
                                          color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== الوجهة =====
                        _sectionTitle('وجهة البنر', Icons.link_rounded),
                        const SizedBox(height: 6),

                        RadioListTile<String>(
                          value: 'store',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('صفحة متجري',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) => setState(() {
                            _targetType = 'store';
                            _productId = null;
                          }),
                        ),
                        RadioListTile<String>(
                          value: 'product',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('عرض محدد',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) =>
                              setState(() => _targetType = 'product'),
                        ),

                        if (_targetType == 'product') ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _productId,
                            isExpanded: true,
                            decoration: _dec('اختر العرض'),
                            items: _products
                                .map((p) => DropdownMenuItem<String>(
                                      value: p['id'].toString(),
                                      child: Text(
                                        (p['name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _productId = v),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ===== البنرات =====
                        _sectionTitle('عدد البنرات', Icons.layers_outlined),
                        const SizedBox(height: 4),
                        Text(
                          'كل بنر يمنحك نصيباً إضافياً من الظهور أمام العملاء · '
                          'المتاح $_available',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: List.generate(_maxSlots, (i) {
                            final n = i + 1;
                            final on = _slots == n;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _slots = n),
                                child: Container(
                                  width: 46,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        on ? brandRed : const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: on
                                            ? brandRed
                                            : Colors.grey.shade300),
                                  ),
                                  child: Center(
                                    child: Text('$n',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: on
                                                ? Colors.white
                                                : Colors.grey.shade700)),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

                        // ===== كود الخصم =====
                        _sectionTitle('كود الخصم', Icons.local_offer_outlined),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _promoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 13),
                          decoration: _dec('اختياري'),
                        ),

                        const SizedBox(height: 20),

                        // ===== الملخّص =====
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // فترة تأسيس مجانية ⇒ لا تفصيل أسعار
                              if (total <= 0) ...[
                                _priceLine('عدد البنرات', '$_slots'),
                              ] else ...[
                                _priceLine('سعر البنر', '$_unitPrice ر.س'),
                                const SizedBox(height: 8),
                                _priceLine('عدد البنرات', '$_slots'),
                                const SizedBox(height: 8),
                                _priceLine('المجموع', '$subtotal ر.س'),
                                const SizedBox(height: 8),
                                _priceLine('ضريبة القيمة المضافة 15%',
                                    '${vat.toStringAsFixed(2)} ر.س'),
                              ],
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                    color: Color(0xFFE5E7EB), height: 1),
                              ),
                              Row(
                                children: [
                                  const Text('الإجمالي',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(
                                    total <= 0
                                        ? 'مجاني — فترة التأسيس'
                                        : '${total.toStringAsFixed(2)} ر.س',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: total <= 0 ? 14 : 17,
                                        fontWeight: FontWeight.bold,
                                        color: brandRed),
                                  ),
                                ],
                              ),
                              if (total > 0)
                                Text(
                                  'الخصم يُحتسب عند تأكيد الشراء',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: Colors.grey.shade500),
                                ),

                              // ===== الرصيد =====
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                    color: Color(0xFFE5E7EB), height: 1),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    enough
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    size: 16,
                                    color: enough ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'رصيدك',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _loadingBalance
                                        ? '...'
                                        : '${_balance.toStringAsFixed(2)} ر.س',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          enough ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (!_loadingBalance && !enough) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'الرصيد غير كافٍ — تحتاج '
                                  '${(total - _balance).toStringAsFixed(2)} ر.س إضافية',
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      MerchantNav.goTo(
                                          MerchantNav.walletSection);
                                    },
                                    icon: const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 17),
                                    label: const Text('اشحن رصيدك',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: brandRed,
                                      side: const BorderSide(color: brandRed),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ===== الموافقة =====
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _termsAccepted,
                              activeColor: brandRed,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) =>
                                  setState(() => _termsAccepted = v ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Text('أوافق على ',
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 12.5)),
                            InkWell(
                              onTap: () async {
                                final agreed =
                                    await showBannerTermsSheet(context);
                                if (agreed == true) {
                                  setState(() => _termsAccepted = true);
                                }
                              },
                              child: const Text(
                                'شروط الإعلان',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: brandRed,
                                  decoration: TextDecoration.underline,
                                  decorationColor: brandRed,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        height: 1.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_busy || !_termsAccepted || !enough)
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : Text(
                                    enough
                                        ? 'تأكيد الشراء'
                                        : 'الرصيد غير كافٍ',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'يُخصم المبلغ من رصيد متجرك فوراً',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: brandRed),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _priceLine(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: brandRed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}


// ============================================================
//              نافذة شراء إعلان الشاشة الرئيسية
// ============================================================

class _SplashBookingSheet extends StatefulWidget {
  final String adDate;
  final int price;
  final String occasion;
  final VoidCallback onDone;

  const _SplashBookingSheet({
    required this.adDate,
    required this.price,
    required this.occasion,
    required this.onDone,
  });

  @override
  State<_SplashBookingSheet> createState() => _SplashBookingSheetState();
}

class _SplashBookingSheetState extends State<_SplashBookingSheet> {
  static const Color brandRed = Color(0xFFD32027);
  static const int _maxKb = 300;
  static const int _w = 1080;
  static const int _h = 1920;

  final supabase = Supabase.instance.client;
  final _promoCtrl = TextEditingController();

  String _targetType = 'store';
  String? _productId;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedUrl;
  bool _termsAccepted = false;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> _products = [];
  double _balance = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadBalance();
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final res = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', uid)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => _products = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('Products error: $e');
    }
  }

  Future<void> _loadBalance() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final res = await supabase
          .from('merchant_wallets')
          .select('balance')
          .eq('merchant_id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _balance = ((res?['balance'] as num?) ?? 0).toDouble();
        _loadingBalance = false;
      });
    } catch (e) {
      debugPrint('Balance error: $e');
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked == null) return;

      final name = picked.name.toLowerCase();
      if (!name.endsWith('.jpg') &&
          !name.endsWith('.jpeg') &&
          !name.endsWith('.webp')) {
        setState(() => _error = 'الصيغة غير مقبولة — استخدم JPG أو WebP');
        return;
      }

      final bytes = await picked.readAsBytes();

      final kb = bytes.lengthInBytes / 1024;
      if (kb > _maxKb) {
        setState(() => _error =
            'حجم الملف ${kb.toStringAsFixed(0)} كيلوبايت — '
            'والحد الأقصى $_maxKb\n'
            'جرّب حفظ الصورة بصيغة JPG لتقليل حجمها');
        return;
      }

      final decoded = await decodeImageFromList(bytes);
      if (decoded.width != _w || decoded.height != _h) {
        setState(() => _error =
            'المقاس غير مطابق\nالصورة: ${decoded.width} × ${decoded.height}\n'
            'المطلوب: $_w × $_h');
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _uploadedUrl = null;
        _error = null;
      });
    } catch (e) {
      debugPrint('Pick error: $e');
      setState(() => _error = 'تعذر قراءة الصورة');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return null;
    if (_uploadedUrl != null) return _uploadedUrl;

    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = (_imageName ?? 'ad.jpg').split('.').last;
      final path = '$uid/${widget.adDate}.$ext';

      await supabase.storage.from('splash_ads').uploadBinary(
            path,
            _imageBytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      _uploadedUrl = supabase.storage.from('splash_ads').getPublicUrl(path);
      return _uploadedUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_imageBytes == null) {
      setState(() => _error = 'ارفع صورة الإعلان أولاً');
      return;
    }
    if (_targetType == 'product' && _productId == null) {
      setState(() => _error = 'اختر العرض المستهدف');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'يجب الموافقة على شروط الإعلان');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final url = await _uploadImage();
      if (url == null) {
        setState(() {
          _error = 'تعذر رفع الصورة';
          _busy = false;
        });
        return;
      }

      final res = await supabase.rpc('purchase_splash_ad', params: {
        'p_ad_date': widget.adDate,
        'p_image_url': url,
        'p_target_type': _targetType,
        'p_product_id': _productId,
        'p_promo_code':
            _promoCtrl.text.trim().isEmpty ? null : _promoCtrl.text.trim(),
        'p_terms_version': 'v1.0',
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onDone();
        _snack(
          'تم الشراء — رصيدك المتبقي '
          '${(map['balance'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س',
          Colors.green,
        );
      } else {
        setState(() {
          _error = map['error']?.toString() ?? 'تعذر إتمام الشراء';
          _busy = false;
        });
      }
    } catch (e) {
      debugPrint('Purchase error: $e');
      setState(() {
        _error = 'تعذر إتمام الشراء، حاول مجدداً';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.price.toDouble();
    final vat = subtotal * 0.15;
    final total = subtotal + vat;
    final enough = _loadingBalance || _balance >= total;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('إعلان الشاشة الرئيسية',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'ليوم ${widget.adDate}'
                          '${widget.occasion.isEmpty ? '' : ' · ${widget.occasion}'}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: brandRed),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المقاس $_w × $_h بكسل · الحد الأقصى $_maxKb '
                          'كيلوبايت · JPG أو WebP',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),

                        const SizedBox(height: 20),

                        _sectionTitle('صورة الإعلان', Icons.image_outlined),
                        const SizedBox(height: 10),

                        if (_imageBytes != null) ...[
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.memory(
                                _imageBytes!,
                                height: 220,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        InkWell(
                          onTap: _busy ? null : _pickImage,
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: _imageBytes != null
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: _imageBytes != null
                                    ? Colors.green.withValues(alpha: 0.35)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _imageBytes != null
                                      ? Icons.check_circle_rounded
                                      : Icons.upload_file_rounded,
                                  size: 19,
                                  color: _imageBytes != null
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _imageBytes != null
                                        ? 'الصورة مطابقة للمواصفات'
                                        : 'اختر صورة الإعلان',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: _imageBytes != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _imageBytes != null
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        _sectionTitle('وجهة الإعلان', Icons.link_rounded),
                        const SizedBox(height: 6),

                        RadioListTile<String>(
                          value: 'store',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('صفحة متجري',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) => setState(() {
                            _targetType = 'store';
                            _productId = null;
                          }),
                        ),
                        RadioListTile<String>(
                          value: 'product',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('عرض محدد',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) =>
                              setState(() => _targetType = 'product'),
                        ),

                        if (_targetType == 'product') ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _productId,
                            isExpanded: true,
                            decoration: _dec('اختر العرض'),
                            items: _products
                                .map((p) => DropdownMenuItem<String>(
                                      value: p['id'].toString(),
                                      child: Text(
                                        (p['name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _productId = v),
                          ),
                        ],

                        const SizedBox(height: 20),

                        _sectionTitle(
                            'كود الخصم', Icons.local_offer_outlined),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _promoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 13),
                          decoration: _dec('اختياري'),
                        ),

                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // فترة تأسيس مجانية ⇒ لا تفصيل أسعار
                              if (total > 0) ...[
                                _priceLine('سعر اليوم',
                                    '${widget.price} ر.س'),
                                const SizedBox(height: 8),
                                _priceLine('ضريبة القيمة المضافة 15%',
                                    '${vat.toStringAsFixed(2)} ر.س'),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                    color: Color(0xFFE5E7EB), height: 1),
                              ),
                              Row(
                                children: [
                                  const Text('الإجمالي',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(
                                    total <= 0
                                        ? 'مجاني — فترة التأسيس'
                                        : '${total.toStringAsFixed(2)} ر.س',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: total <= 0 ? 14 : 17,
                                        fontWeight: FontWeight.bold,
                                        color: brandRed),
                                  ),
                                ],
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                    color: Color(0xFFE5E7EB), height: 1),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    enough
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    size: 16,
                                    color:
                                        enough ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('رصيدك',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                  const Spacer(),
                                  Text(
                                    _loadingBalance
                                        ? '...'
                                        : '${_balance.toStringAsFixed(2)} ر.س',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          enough ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (!_loadingBalance && !enough) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'الرصيد غير كافٍ — تحتاج '
                                  '${(total - _balance).toStringAsFixed(2)} ر.س إضافية',
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      MerchantNav.goTo(
                                          MerchantNav.walletSection);
                                    },
                                    icon: const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 17),
                                    label: const Text('اشحن رصيدك',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: brandRed,
                                      side: const BorderSide(color: brandRed),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _termsAccepted,
                              activeColor: brandRed,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) =>
                                  setState(() => _termsAccepted = v ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Text('أوافق على ',
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 12.5)),
                            InkWell(
                              onTap: () async {
                                final agreed =
                                    await showBannerTermsSheet(context);
                                if (agreed == true) {
                                  setState(() => _termsAccepted = true);
                                }
                              },
                              child: const Text(
                                'شروط الإعلان',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: brandRed,
                                  decoration: TextDecoration.underline,
                                  decorationColor: brandRed,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        height: 1.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_busy || !_termsAccepted || !enough)
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : Text(
                                    enough
                                        ? 'تأكيد الشراء'
                                        : 'الرصيد غير كافٍ',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'يُخصم المبلغ من رصيد متجرك فوراً',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: brandRed),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _priceLine(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: brandRed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}


// ============================================================
//        نافذة تعديل إعلان — بنر أو شاشة رئيسية
// ============================================================

class _AdEditSheet extends StatefulWidget {
  /// banner أو splash
  final String kind;
  final String id;
  final String currentTarget;
  final String? currentProduct;
  final int width;
  final int height;
  final int maxKb;
  final VoidCallback onDone;

  const _AdEditSheet({
    required this.kind,
    required this.id,
    required this.currentTarget,
    required this.currentProduct,
    required this.width,
    required this.height,
    required this.maxKb,
    required this.onDone,
  });

  @override
  State<_AdEditSheet> createState() => _AdEditSheetState();
}

class _AdEditSheetState extends State<_AdEditSheet> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  late String _targetType;
  String? _productId;
  Uint8List? _imageBytes;
  String? _imageName;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _targetType = widget.currentTarget;
    _productId = widget.currentProduct;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final res = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', uid)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => _products = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('Products error: $e');
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked == null) return;

      final name = picked.name.toLowerCase();
      if (!name.endsWith('.jpg') &&
          !name.endsWith('.jpeg') &&
          !name.endsWith('.webp')) {
        setState(() => _error = 'الصيغة غير مقبولة — استخدم JPG أو WebP');
        return;
      }

      final bytes = await picked.readAsBytes();

      final kb = bytes.lengthInBytes / 1024;
      if (kb > widget.maxKb) {
        setState(() => _error =
            'حجم الملف ${kb.toStringAsFixed(0)} كيلوبايت — '
            'والحد الأقصى ${widget.maxKb}\n'
            'جرّب حفظ الصورة بصيغة JPG لتقليل حجمها');
        return;
      }

      final decoded = await decodeImageFromList(bytes);
      if (decoded.width != widget.width || decoded.height != widget.height) {
        setState(() => _error =
            'المقاس غير مطابق\nالصورة: ${decoded.width} × ${decoded.height}\n'
            'المطلوب: ${widget.width} × ${widget.height}');
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _error = null;
      });
    } catch (e) {
      debugPrint('Pick error: $e');
      setState(() => _error = 'تعذر قراءة الصورة');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return '';
    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = (_imageName ?? 'ad.jpg').split('.').last;
      final bucket =
          widget.kind == 'splash' ? 'splash_ads' : 'banners_bucket';
      final path =
          '$uid/edit-${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from(bucket).uploadBinary(
            path,
            _imageBytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      return supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_targetType == 'product' && _productId == null) {
      setState(() => _error = 'اختر العرض المستهدف');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final url = await _uploadImage();
      if (url == null) {
        setState(() {
          _error = 'تعذر رفع الصورة';
          _busy = false;
        });
        return;
      }

      final fn = widget.kind == 'splash'
          ? 'update_splash_ad'
          : 'update_banner_booking';

      final idParam =
          widget.kind == 'splash' ? 'p_ad_id' : 'p_booking_id';

      final res = await supabase.rpc(fn, params: {
        idParam: widget.id,
        'p_image_url': url,
        'p_target_type': _targetType,
        'p_product_id': _productId,
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onDone();
        _snack('حُفظ التعديل — وأُعيد الإعلان للمراجعة', Colors.green);
      } else {
        setState(() {
          _error = map['error']?.toString() ?? 'تعذر الحفظ';
          _busy = false;
        });
      }
    } catch (e) {
      debugPrint('Update error: $e');
      setState(() {
        _error = 'تعذر حفظ التعديل، حاول مجدداً';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.kind == 'splash'
                              ? 'تعديل إعلان الشاشة الرئيسية'
                              : 'تعديل البنر',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'أي تعديل يُعيد الإعلان لمراجعة الإدارة',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            const Icon(Icons.image_outlined,
                                size: 17, color: brandRed),
                            const SizedBox(width: 9),
                            const Text('الصورة',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              '${widget.width} × ${widget.height} · '
                              '${widget.maxKb} ك.ب',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10.5,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        if (_imageBytes != null) ...[
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.memory(
                                _imageBytes!,
                                height: widget.kind == 'splash' ? 200 : 110,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        InkWell(
                          onTap: _busy ? null : _pickImage,
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: _imageBytes != null
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: _imageBytes != null
                                    ? Colors.green.withValues(alpha: 0.35)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _imageBytes != null
                                      ? Icons.check_circle_rounded
                                      : Icons.upload_file_rounded,
                                  size: 19,
                                  color: _imageBytes != null
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _imageBytes != null
                                        ? 'صورة جديدة مطابقة'
                                        : 'اختر صورة جديدة — أو أبقِ الحالية',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      color: _imageBytes != null
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: const [
                            Icon(Icons.link_rounded,
                                size: 17, color: brandRed),
                            SizedBox(width: 9),
                            Text('الوجهة',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),

                        RadioListTile<String>(
                          value: 'store',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('صفحة متجري',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) => setState(() {
                            _targetType = 'store';
                            _productId = null;
                          }),
                        ),
                        RadioListTile<String>(
                          value: 'product',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('عرض محدد',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) =>
                              setState(() => _targetType = 'product'),
                        ),

                        if (_targetType == 'product') ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _productId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'اختر العرض',
                              hintStyle: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey.shade400),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: const BorderSide(
                                    color: brandRed, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                            ),
                            items: _products
                                .map((p) => DropdownMenuItem<String>(
                                      value: p['id'].toString(),
                                      child: Text(
                                        (p['name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _productId = v),
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        height: 1.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('حفظ التعديل',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
