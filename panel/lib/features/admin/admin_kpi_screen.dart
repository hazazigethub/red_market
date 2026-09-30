import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:supabase_flutter/supabase_flutter.dart';

/// شاشة مؤشرات الأداء — المصدر: kpi_daily (تُحسب كل منتصف ليل)
class AdminKpiScreen extends StatefulWidget {
  const AdminKpiScreen({super.key});

  @override
  State<AdminKpiScreen> createState() => _AdminKpiScreenState();
}

class _AdminKpiScreenState extends State<AdminKpiScreen> {
  static const Color brandRed = Color(0xFFD32027);
  static const Color line = Color(0xFFEDEFF3);
  static const Color textMain = Color(0xFF1F2937);
  static const Color green = Color(0xFF2E7D32);
  static const double dbLimit = 8 * 1024 * 1024 * 1024;
  static const double storageLimit = 100 * 1024 * 1024 * 1024;

  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _refreshing = false;
  int _days = 7; // 7 أو 30
  bool _paidBasis = true; // المدفوع فعلاً، أو سعر الباقة الأصلي

  /// day -> metric -> value
  final Map<DateTime, Map<String, double>> _data = {};
  Map<String, double> _targets = {};
  Map<String, dynamic>? _inputs;
  List<Map<String, dynamic>> _zeroQueries = [];
  List<Map<String, dynamic>> _atRisk = [];
  Map<String, dynamic>? _fill;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _today {
    final n = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = _today.subtract(const Duration(days: 75));
      final rows = await supabase
          .from('kpi_daily')
          .select('day, metric, value')
          .gte('day', DateFormat('yyyy-MM-dd').format(from))
          .limit(10000);
      _data.clear();
      for (final r in rows) {
        final d = DateTime.parse(r['day'] as String);
        final day = DateTime(d.year, d.month, d.day);
        _data.putIfAbsent(day, () => {})[r['metric'] as String] =
            (r['value'] as num).toDouble();
      }

      final t = await supabase.from('kpi_targets').select();
      _targets = {
        for (final r in t) r['metric'] as String: (r['target'] as num).toDouble()
      };

      final inp = await supabase
          .from('kpi_inputs')
          .select()
          .order('month', ascending: false)
          .limit(1);
      _inputs = inp.isNotEmpty ? Map<String, dynamic>.from(inp.first) : null;

      final z = await supabase.rpc('kpi_zero_result_queries',
          params: {'p_days': _days, 'p_limit': 10});
      _zeroQueries = List<Map<String, dynamic>>.from(z ?? []);

      final a = await supabase.rpc('kpi_at_risk_stores', params: {'p_limit': 20});
      _atRisk = List<Map<String, dynamic>>.from(a ?? []);

      final f = await supabase.rpc('kpi_fill_rates', params: {'p_weeks': 4});
      _fill = f == null ? null : Map<String, dynamic>.from(f as Map);
    } catch (e) {
      _snack('تعذر تحميل المؤشرات: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await supabase.rpc('kpi_refresh_today');
      await _load();
      _snack('تم تحديث مؤشرات اليوم', green);
    } catch (e) {
      _snack('تعذر التحديث: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _refreshing = false);
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

  // ===================== الحساب =====================

  List<DateTime> _range(int offset) {
    final end = _today.subtract(Duration(days: offset * _days));
    return List.generate(
        _days, (i) => end.subtract(Duration(days: _days - 1 - i)));
  }

  double _sum(String m, [int offset = 0]) =>
      _range(offset).fold(0.0, (a, d) => a + (_data[d]?[m] ?? 0));

  /// آخر قيمة مسجلة في الفترة (للقطات مثل الإيراد الشهري)
  double? _last(String m, [int offset = 0]) {
    for (final d in _range(offset).reversed) {
      final v = _data[d]?[m];
      if (v != null) return v;
    }
    return null;
  }

  /// أول قيمة مسجلة في الفترة
  double? _first(String m, [int offset = 0]) {
    for (final d in _range(offset)) {
      final v = _data[d]?[m];
      if (v != null) return v;
    }
    return null;
  }

  double? _ratio(double num, double den) => den > 0 ? num / den : null;

  String get _b => _paidBasis ? 'paid' : 'list';

  double _netNew([int o = 0]) =>
      _sum('new_mrr_$_b', o) +
      _sum('expansion_mrr_$_b', o) -
      _sum('contraction_mrr_$_b', o) -
      _sum('churned_mrr_$_b', o);

  double? _arpa([int o = 0]) {
    final mrr = _last('mrr_$_b', o);
    final n = _last(_paidBasis ? 'paying_stores' : 'subscribed_stores', o);
    return (mrr == null || n == null) ? null : _ratio(mrr, n);
  }

  static const _sources = {
    'sub': 'الاشتراكات',
    'banner': 'البنرات',
    'splash': 'الإعلان الافتتاحي',
    'campaign': 'الحملات',
    'expo': 'المعارض',
    'recording': 'تسجيل البث',
  };

  double _revenue(String basis, [int o = 0]) => _sources.keys
      .fold(0.0, (a, k) => a + _sum('rev_${k}_$basis', o));

  double _codeDiscount([int o = 0]) => _revenue('list', o) - _revenue('paid', o);

  double? _churnRate([int o = 0]) {
    final start = _first(_paidBasis ? 'paying_stores' : 'subscribed_stores', o);
    return start == null ? null : _ratio(_sum('churned_stores', o), start);
  }

  double? _lift() {
    final pv = _last('pro_views_7d'), po = _last('pro_offers');
    final ov = _last('other_views_7d'), oo = _last('other_offers');
    if (pv == null || po == null || ov == null || oo == null) return null;
    final p = _ratio(pv, po), o = _ratio(ov, oo);
    return (p == null || o == null) ? null : _ratio(p, o);
  }

  double? _inputVal(String k) => (_inputs?[k] as num?)?.toDouble();

  // ===================== التنسيق =====================

  String _fmt(double? v, {int dec = 0}) =>
      v == null
          ? '—'
          : NumberFormat(dec > 0 ? '#,##0.${'0' * dec}' : '#,##0', 'en').format(v);
  String _sar(double? v) => v == null ? '—' : '${_fmt(v, dec: v.abs() < 100 ? 1 : 0)} ر.س';
  String _pct(double? v) => v == null ? '—' : '${_fmt(v * 100, dec: 1)}%';

  // ===================== الواجهة =====================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: brandRed));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: RefreshIndicator(
          color: brandRed,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _header(),
              if (_data.isEmpty) _empty(),
              if (_data.isNotEmpty) ...[
                _northStar(),
                _section('الإيرادات', Icons.payments_outlined, _revenueCards()),
                _section('المنتجات الإعلانية', Icons.campaign_outlined, _adsCards()),
                _section('المتاجر', Icons.storefront_outlined, _storeCards()),
                _section('العملاء', Icons.groups_outlined, _userCards()),
                _section('القيمة للتاجر', Icons.handshake_outlined, _valueCards()),
                _section('الجودة والمعارض', Icons.verified_outlined, _qualityCards()),
                _section('التكلفة والبنية', Icons.dns_outlined, _costCards()),
                _listsRow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('مؤشرات الأداء',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textMain)),
          const SizedBox(width: 12),
          _chip('آخر 7 أيام', _days == 7, () {
            setState(() => _days = 7);
            _load();
          }),
          _chip('آخر 30 يوماً', _days == 30, () {
            setState(() => _days = 30);
            _load();
          }),
          const SizedBox(width: 6),
          _chip('المدفوع فعلاً', _paidBasis, () => setState(() => _paidBasis = true)),
          _chip('سعر الباقة الأصلي', !_paidBasis,
              () => setState(() => _paidBasis = false)),
          const SizedBox(width: 6),
          _outlineBtn(Icons.edit_note_rounded, 'المدخلات الشهرية', _editInputs),
          _outlineBtn(
              Icons.refresh_rounded,
              _refreshing ? 'جاري التحديث...' : 'تحديث اليوم',
              _refreshing ? null : _refresh),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: active ? brandRed : line),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : textMain)),
      ),
    );
  }

  Widget _outlineBtn(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: brandRed),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12.5, color: textMain)),
        ]),
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: _box(),
      child: const Text(
          'لا توجد قيم بعد. اضغط «تحديث اليوم» لحساب مؤشرات اليوم الأول.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
    );
  }

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      );

  Widget _northStar() {
    final cur = _sum('outbound_clicks');
    final prev = _sum('outbound_clicks', 1);
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: brandRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المؤشر الرئيسي · الانتقالات إلى المتاجر',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(_fmt(cur),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(
                  'التطبيق ${_fmt(_sum('clicks_app'))} · الموقع ${_fmt(_sum('clicks_web'))} · المعارض ${_fmt(_sum('clicks_expo'))}',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 12.5, color: Colors.white),
                ),
              ],
            ),
          ),
          _delta(cur, prev, true, onRed: true),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> cards) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: brandRed),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textMain)),
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 1100
                ? 4
                : c.maxWidth > 800
                    ? 3
                    : c.maxWidth > 520
                        ? 2
                        : 1;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards.map((e) => SizedBox(width: w, child: e)).toList(),
            );
          }),
        ],
      ),
    );
  }

  /// بطاقة مؤشر: الاسم، القيمة، التغير عن الفترة السابقة، القرار
  Widget _card({
    required String name,
    required String value,
    required String decision,
    String? sub,
    double? cur,
    double? prev,
    bool higherIsBetter = true,
    bool alert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alert ? brandRed : line, width: alert ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
              ),
              if (cur != null && prev != null) _delta(cur, prev, higherIsBetter),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: alert ? brandRed : textMain)),
          if (sub != null)
            Text(sub,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('القرار: $decision',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    height: 1.5,
                    color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _delta(double cur, double prev, bool higherIsBetter, {bool onRed = false}) {
    if (prev == 0 && cur == 0) return const SizedBox.shrink();
    final up = cur >= prev;
    final good = up == higherIsBetter;
    final pct = prev == 0 ? null : (cur - prev) / prev.abs();
    final color = onRed
        ? Colors.white
        : (cur == prev ? Colors.grey : (good ? green : brandRed));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: onRed ? Colors.white24 : color.withAlpha(25),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13, color: color),
        Text(pct == null ? 'جديد' : '${_fmt(pct.abs() * 100, dec: 0)}%',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }

  // ===================== البطاقات =====================

  List<Widget> _revenueCards() {
    final mrr = _last('mrr_$_b');
    final mrrPrev = _last('mrr_$_b', 1);
    final net = _netNew(), netPrev = _netNew(1);
    final code = _codeDiscount(), codePrev = _codeDiscount(1);

    final totalRev = _revenue(_b);
    final mix = _sources.entries
        .map((e) => MapEntry(e.value, _sum('rev_${e.key}_$_b')))
        .where((e) => e.value > 0)
        .map((e) => '${e.key} ${_pct(_ratio(e.value, totalRev))}')
        .join(' · ');

    final cash = _inputVal('cash_balance');
    final costs = (_inputVal('marketing_spend') ?? 0) +
        (_inputVal('infra_cost') ?? 0) +
        (_inputVal('other_costs') ?? 0);
    final monthlyNet = (_revenue('paid') - _sum('refunds')) * (30 / _days);
    final burn = costs - monthlyNet;
    final runway = (cash == null || _inputs == null)
        ? null
        : (burn <= 0 ? double.infinity : cash / burn);

    return [
      _card(
        name: 'الإيراد الشهري المتكرر (MRR)',
        value: _sar(mrr),
        sub: 'السنوي (ARR): ${_sar(mrr == null ? null : mrr * 12)}',
        cur: mrr,
        prev: mrrPrev,
        decision: 'متى تفعّل بوابة الدفع، وكم يُتوقع دخلاً بعدها',
      ),
      _card(
        name: 'صافي نمو الإيراد (Net New MRR)',
        value: _sar(net),
        sub:
            'جديد ${_sar(_sum('new_mrr_$_b'))} · ترقية ${_sar(_sum('expansion_mrr_$_b'))} · تخفيض ${_sar(_sum('contraction_mrr_$_b'))} · مفقود ${_sar(_sum('churned_mrr_$_b'))}',
        cur: net,
        prev: netPrev,
        alert: net < 0,
        decision: 'أين تتدخل: الاستقطاب، أو الترقية، أو منع الإلغاء',
      ),
      _card(
        name: 'متوسط الإيراد لكل متجر (ARPA)',
        value: _sar(_arpa()),
        cur: _arpa(),
        prev: _arpa(1),
        decision: 'هل تعدّل أسعار الباقات أو مزاياها',
      ),
      _card(
        name: 'قيمة الأكواد الممنوحة',
        value: _sar(code),
        sub: 'الفرق بين السعر الأصلي والمدفوع في كل المصادر',
        cur: code,
        prev: codePrev,
        higherIsBetter: false,
        decision: 'هل توقف الأكواد المجانية أو تقلل نسبتها',
      ),
      _card(
        name: 'مزيج الإيراد (Revenue Mix)',
        value: _sar(totalRev),
        sub: mix.isEmpty ? 'لا إيراد في الفترة' : mix,
        decision: 'أي منتج إعلاني تطوّره، وأيها توقفه',
      ),
      _card(
        name: 'مدة الاستمرار (Runway)',
        value: runway == null
            ? '—'
            : (runway.isInfinite ? 'لا استهلاك' : '${_fmt(runway, dec: 1)} شهر'),
        sub: _inputs == null ? 'أدخل السيولة والمصاريف في «المدخلات الشهرية»' : null,
        alert: runway != null && !runway.isInfinite && runway < 6,
        decision: 'متى تحتاج تمويلاً أو خفض مصاريف',
      ),
    ];
  }

  List<Widget> _adsCards() {
    final weeks = List<Map<String, dynamic>>.from(_fill?['banners'] ?? []);
    final today = DateFormat('yyyy-MM-dd').format(_today);
    final upcoming = weeks.where((w) => (w['week_start'] as String).compareTo(today) >= 0);
    double booked = 0, total = 0;
    for (final w in upcoming) {
      booked += ((w['wide_booked'] ?? 0) as num) + ((w['small_booked'] ?? 0) as num);
      total += ((w['wide_total'] ?? 0) as num) + ((w['small_total'] ?? 0) as num);
    }
    final splash = _fill?['splash'] as Map?;
    final sOpen = ((splash?['open_days'] ?? 0) as num).toDouble();
    final sBooked = ((splash?['booked_days'] ?? 0) as num).toDouble();

    return [
      _card(
        name: 'إشغال البنرات (الأسابيع القادمة)',
        value: _pct(_ratio(booked, total)),
        sub: '${_fmt(booked)} من ${_fmt(total)} خانة',
        decision: 'رفع السعر عند الامتلاء، وخفضه أو تقليل الخانات عند الفراغ',
      ),
      _card(
        name: 'إشغال الإعلان الافتتاحي (±30 يوماً)',
        value: _pct(_ratio(sBooked, sOpen)),
        sub: '${_fmt(sBooked)} من ${_fmt(sOpen)} يوم مفتوح',
        decision: 'رفع سعر الأيام أو خفضه',
      ),
    ];
  }

  List<Widget> _storeCards() {
    final total = _last('total_stores');
    final target = _targets['total_stores'] ?? 5000;
    final newS = _sum('new_stores'), newPrev = _sum('new_stores', 1);
    final pace = (target - (total ?? 0)) /
        (DateTime(2027, 9, 30).difference(_today).inDays.clamp(1, 9999)) *
        _days;
    final act = _ratio(_sum('activation_done'), _sum('activation_cohort'));
    final actPrev = _ratio(_sum('activation_done', 1), _sum('activation_cohort', 1));
    final trial = _ratio(_sum('trials_converted'), _sum('trials_ended'));
    final trialPrev = _ratio(_sum('trials_converted', 1), _sum('trials_ended', 1));
    final churn = _churnRate(), churnPrev = _churnRate(1);
    final zero = _ratio(_sum('searches_zero'), _sum('searches'));

    return [
      _card(
        name: 'المتاجر الجديدة',
        value: _fmt(newS),
        sub:
            'الإجمالي ${_fmt(total)} من ${_fmt(target)} · المطلوب ${_fmt(pace)} في الفترة',
        cur: newS,
        prev: newPrev,
        alert: newS < pace,
        decision: 'زيادة حملة الاستقطاب أو تغيير قناتها',
      ),
      _card(
        name: 'تفعيل المتاجر',
        value: _pct(act),
        sub: 'نشرت أول عرض خلال 7 أيام من التسجيل',
        cur: act,
        prev: actPrev,
        decision: 'تبسيط خطوات البدء في اللوحة',
      ),
      _card(
        name: 'التحويل من التجربة إلى الدفع',
        value: _pct(trial),
        sub: 'تجارب انتهت: ${_fmt(_sum('trials_ended'))}',
        cur: trial,
        prev: trialPrev,
        decision: 'تعديل مدة التجربة أو سعر الباقة الأساسية',
      ),
      _card(
        name: 'تسرب المتاجر (Churn)',
        value: _pct(churn),
        sub: 'متاجر غادرت: ${_fmt(_sum('churned_stores'))}',
        cur: churn,
        prev: churnPrev,
        higherIsBetter: false,
        alert: (churn ?? 0) > 0.05,
        decision: 'مراجعة القيمة التي يحصل عليها التاجر',
      ),
      _card(
        name: 'متاجر معرّضة للمغادرة',
        value: _fmt(_atRisk.length.toDouble()),
        sub: 'لها عروض ولم يصلها انتقال خلال 14 يوماً (القائمة أسفل الصفحة)',
        alert: _atRisk.isNotEmpty,
        decision: 'التواصل معها قبل أن تغادر',
      ),
      _card(
        name: 'البحث بلا نتائج',
        value: _pct(zero),
        sub: 'من ${_fmt(_sum('searches'))} عملية بحث (الكلمات أسفل الصفحة)',
        higherIsBetter: false,
        decision: 'أي نوع من المتاجر تستقطب أولاً',
      ),
    ];
  }

  List<Widget> _userCards() {
    final total = _last('total_users');
    final target = _targets['total_users'] ?? 1000000;
    final newU = _sum('new_users'), newPrev = _sum('new_users', 1);
    final pace = (target - (total ?? 0)) /
        (DateTime(2027, 9, 30).difference(_today).inDays.clamp(1, 9999)) *
        _days;
    final ret = _ratio(_sum('retention_w4_done'), _sum('retention_w4_cohort'));
    final retPrev =
        _ratio(_sum('retention_w4_done', 1), _sum('retention_w4_cohort', 1));

    return [
      _card(
        name: 'العملاء الجدد',
        value: _fmt(newU),
        sub:
            'الإجمالي ${_fmt(total)} من ${_fmt(target)} · المطلوب ${_fmt(pace)} في الفترة',
        cur: newU,
        prev: newPrev,
        alert: newU < pace,
        decision: 'زيادة التسويق للعملاء أو تغيير قناته',
      ),
      _card(
        name: 'الاحتفاظ بعد 4 أسابيع',
        value: _pct(ret),
        sub:
            'النشطون: أسبوعياً ${_fmt(_last('wau'))} · شهرياً ${_fmt(_last('mau'))}',
        cur: ret,
        prev: retPrev,
        decision: 'هل المشكلة في جلب العملاء أم في إبقائهم',
      ),
    ];
  }

  List<Widget> _valueCards() {
    final ctr = _ratio(_sum('clicks_product'), _sum('offer_views'));
    final ctrPrev = _ratio(_sum('clicks_product', 1), _sum('offer_views', 1));
    final clicked = _last('stores_clicked_7d'), active = _last('active_stores');
    final value = (clicked == null || active == null) ? null : _ratio(clicked, active);
    final lift = _lift();

    return [
      _card(
        name: 'معدل الانتقال من العرض إلى المتجر',
        value: _pct(ctr),
        sub: 'مشاهدات العروض ${_fmt(_sum('offer_views'))}',
        cur: ctr,
        prev: ctrPrev,
        decision: 'تحسين عرض العروض وتصميم زر الانتقال',
      ),
      _card(
        name: 'المتاجر التي وصلتها قيمة',
        value: _pct(value),
        sub: '${_fmt(clicked)} من ${_fmt(active)} متجر نشط خلال 7 أيام',
        alert: value != null && value < 0.5,
        decision: 'إبراز المتاجر التي لا يصلها أحد',
      ),
      _card(
        name: 'قيمة أولوية الباقة الاحترافية',
        value: lift == null ? '—' : '${_fmt(lift, dec: 2)}×',
        sub: 'مشاهدات عرض الاحترافية مقارنة ببقية الباقات',
        alert: lift != null && lift < 1.1,
        decision: 'هل الباقة الاحترافية تستحق سعرها',
      ),
    ];
  }

  List<Widget> _qualityCards() {
    final fd = _ratio(_last('false_discount_offers') ?? 0, _last('discount_offers') ?? 0);
    final booths = _last('expo_live_booths');
    final leads = _sum('expo_leads');
    return [
      _card(
        name: 'نسبة الخصومات غير الحقيقية',
        value: _pct(fd),
        sub: 'عروض خصم بلا سعر قبل الخصم، أو سعرها لم ينخفض',
        higherIsBetter: false,
        alert: (fd ?? 0) > 0.05,
        decision: 'إيقاف عروض أو تحذير تجار',
      ),
      _card(
        name: 'العملاء المحتملون لكل جناح',
        value: booths == null || booths == 0
            ? '—'
            : _fmt(leads / booths, dec: 1),
        sub: 'عملاء محتملون ${_fmt(leads)} · أجنحة في معارض مباشرة ${_fmt(booths)}',
        decision: 'هل تستحق المعارض الاستمرار، وكم تسعّر المشاركة',
      ),
    ];
  }

  List<Widget> _costCards() {
    final arpa = _arpa();
    final churn = _churnRate();
    final monthlyChurn = churn == null ? null : churn * (30 / _days);
    final ltv = (arpa == null || monthlyChurn == null || monthlyChurn == 0)
        ? null
        : arpa / monthlyChurn;
    final spend = _inputVal('marketing_spend');
    final newPaid = _sum('new_paid_stores') * (30 / _days);
    final cac = (spend == null || newPaid == 0) ? null : spend / newPaid;
    final ratio = (ltv == null || cac == null || cac == 0) ? null : ltv / cac;

    final infra = _inputVal('infra_cost');
    final mau = _last('mau');
    final perMau = (infra == null || mau == null || mau == 0) ? null : infra / mau;

    final db = _last('db_bytes'), st = _last('storage_bytes');
    final dbPct = db == null ? null : db / dbLimit;
    final stPct = st == null ? null : st / storageLimit;
    final worst = [dbPct ?? 0, stPct ?? 0].reduce((a, b) => a > b ? a : b);

    return [
      _card(
        name: 'قيمة المتجر ÷ تكلفة استقطابه (LTV/CAC)',
        value: ratio == null ? '—' : '${_fmt(ratio, dec: 1)}×',
        sub: 'LTV ${_sar(ltv)} · CAC ${_sar(cac)}',
        alert: ratio != null && ratio < 3,
        decision: 'كم تنفق على الاستقطاب، وهل تزيده أو توقفه',
      ),
      _card(
        name: 'تكلفة الاستضافة لكل عميل نشط',
        value: perMau == null ? '—' : _sar(perMau),
        sub: infra == null ? 'أدخل فاتورة الاستضافة في «المدخلات الشهرية»' : null,
        decision: 'هل تعيد تصميم ما يستهلك التكلفة',
      ),
      _card(
        name: 'استهلاك قاعدة البيانات والتخزين',
        value: _pct(worst),
        sub: 'القاعدة ${_pct(dbPct)} من 8 جيجا · التخزين ${_pct(stPct)} من 100 جيجا',
        alert: worst > 0.7,
        decision: 'متى ترقّي خطة الاستضافة',
      ),
    ];
  }

  Widget _listsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 800;
        final a = _listBox(
          'متاجر معرّضة للمغادرة',
          _atRisk.isEmpty
              ? const ['لا توجد']
              : _atRisk.map((r) {
                  final last = r['last_click_at'] == null
                      ? 'لم يصلها انتقال'
                      : 'آخر انتقال ${DateFormat('yyyy-MM-dd').format(DateTime.parse(r['last_click_at']).toLocal())}';
                  return '${r['store_name'] ?? 'متجر'} · ${r['active_offers']} عرض · $last';
                }).toList(),
        );
        final b = _listBox(
          'أكثر كلمات البحث بلا نتائج',
          _zeroQueries.isEmpty
              ? const ['لا توجد']
              : _zeroQueries.map((r) => '${r['query']} · ${r['searches']} مرة').toList(),
        );
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 12),
                  Expanded(child: b),
                ],
              )
            : Column(children: [a, const SizedBox(height: 12), b]);
      }),
    );
  }

  Widget _listBox(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textMain)),
          const SizedBox(height: 8),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(t,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: Colors.grey.shade800)),
              )),
        ],
      ),
    );
  }

  // ===================== المدخلات الشهرية =====================

  Future<void> _editInputs() async {
    final month = DateTime(_today.year, _today.month, 1);
    final monthKey = DateFormat('yyyy-MM-dd').format(month);
    final same = _inputs != null && _inputs!['month'] == monthKey;
    String init(String k) =>
        same && _inputs![k] != null ? '${_inputs![k]}' : '';

    final cash = TextEditingController(text: init('cash_balance'));
    final mkt = TextEditingController(text: init('marketing_spend'));
    final infra = TextEditingController(text: init('infra_cost'));
    final other = TextEditingController(text: init('other_costs'));

    Widget field(TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: brandRed, width: 1.4)),
            ),
          ),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('المدخلات الشهرية · ${DateFormat('yyyy-MM').format(month)}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              field(cash, 'السيولة المتاحة (ر.س)'),
              field(mkt, 'الإنفاق التسويقي هذا الشهر (ر.س)'),
              field(infra, 'فاتورة الاستضافة هذا الشهر (ر.س)'),
              field(other, 'مصاريف أخرى هذا الشهر (ر.س)'),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حفظ',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      double? p(TextEditingController c) => double.tryParse(c.text.trim());
      try {
        await supabase.from('kpi_inputs').upsert({
          'month': monthKey,
          'cash_balance': p(cash),
          'marketing_spend': p(mkt),
          'infra_cost': p(infra),
          'other_costs': p(other),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await _load();
        _snack('تم حفظ المدخلات', green);
      } catch (e) {
        _snack('تعذر الحفظ: $e', Colors.red);
      }
    }
  }
}
