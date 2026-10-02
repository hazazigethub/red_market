// panel/lib/features/admin/payment_dashboard.dart
// لوحة المدفوعات للإدارة — بيانات حقيقية من get_admin_payment_stats
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentDashboard extends StatefulWidget {
  const AdminPaymentDashboard({super.key});

  @override
  State<AdminPaymentDashboard> createState() => _AdminPaymentDashboardState();
}

class _AdminPaymentDashboardState extends State<AdminPaymentDashboard> {
  static const brandRed = Color(0xFFD32027);
  static const _border = Color(0xFFEDEFF3);
  static const _text = Color(0xFF1F2937);
  static const _muted = Color(0xFF757575);

  static const _periods = [7, 30, 90];

  int _days = 30;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client
          .rpc('get_admin_payment_stats', params: {'p_days': _days});
      final map = Map<String, dynamic>.from(res as Map);
      if (!mounted) return;
      setState(() {
        if (map['ok'] == true) {
          _data = map;
        } else {
          _error = map['error']?.toString() ?? 'تعذّر جلب البيانات';
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Payment stats error: $e');
      if (mounted) {
        setState(() {
          _error = 'تعذّر جلب البيانات';
          _loading = false;
        });
      }
    }
  }

  double _num(String k) => ((_data[k] as num?) ?? 0).toDouble();
  int _int(String k) => ((_data[k] as num?) ?? 0).toInt();

  String _money(double v) => '${v.toStringAsFixed(2)} ر.س';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
        body: RefreshIndicator(
          color: brandRed,
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(isDark),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: CircularProgressIndicator(color: brandRed)),
                      )
                    else if (_error != null)
                      _errorBox(isDark)
                    else ...[
                      _kpis(isDark),
                      const SizedBox(height: 20),
                      _chart(isDark),
                      const SizedBox(height: 20),
                      _recent(isDark),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== الرأس وفترة العرض =====================

  Widget _header(bool isDark) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عمليات الدفع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : _text,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'شحن الأرصدة عبر MyFatoorah — الناجح والفاشل وآخر العمليات',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in _periods) ...[
              _periodTab(d, isDark),
              if (d != _periods.last) const SizedBox(width: 8),
            ],
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 44,
              child: IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, color: brandRed),
                tooltip: 'تحديث',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _periodTab(int d, bool isDark) {
    final active = d == _days;
    return InkWell(
      onTap: active || _loading
          ? null
          : () {
              setState(() => _days = d);
              _load();
            },
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? brandRed : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: active ? brandRed : (isDark ? Colors.white10 : _border)),
        ),
        child: Text(
          '$d يوم',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : (isDark ? Colors.white70 : _text),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(bool isDark) {
    return _card(
      isDark,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: brandRed, size: 36),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }

  // ===================== المؤشرات =====================

  Widget _kpis(bool isDark) {
    final completed = _int('completed_count');
    final failed = _int('failed_count');
    final attempts = completed + failed;
    final rate = attempts == 0 ? 0 : (completed * 100 / attempts);

    final items = [
      ('المستلم', _money(_num('total_received')),
          Icons.account_balance_wallet_rounded, Colors.green),
      ('عمليات ناجحة', '$completed', Icons.check_circle_outline_rounded, Colors.green),
      ('نسبة النجاح', '${rate.toStringAsFixed(0)}%', Icons.trending_up_rounded, Colors.orange),
      ('عمليات فاشلة', '$failed', Icons.error_outline_rounded, brandRed),
      ('لم تكتمل بعد', '${_int('pending_count')}', Icons.hourglass_empty_rounded, Colors.blue),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 560 ? 2 : 1);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final it in items)
              SizedBox(width: w, child: _kpiCard(it.$1, it.$2, it.$3, it.$4, isDark)),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, bool isDark) {
    return _card(
      isDark,
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== الرسم البياني =====================

  Widget _chart(bool isDark) {
    final daily = List<Map<String, dynamic>>.from(
        (_data['daily'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    final spots = <FlSpot>[
      for (var i = 0; i < daily.length; i++)
        FlSpot(i.toDouble(), ((daily[i]['amount'] as num?) ?? 0).toDouble()),
    ];
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    final step = daily.length <= 7 ? 1 : (daily.length / 6).ceil();

    String dayLabel(int i) {
      if (i < 0 || i >= daily.length) return '';
      final d = DateTime.tryParse(daily[i]['day'].toString());
      return d == null ? '' : '${d.day}/${d.month}';
    }

    return _card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المستلم يومياً',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _text,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 10 : maxY * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: isDark ? Colors.white10 : _border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        // لا نعرض قيمة الحد الأعلى حتى لا تتداخل مع أقرب خط
                        getTitlesWidget: (value, meta) => value == meta.max
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  value.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 10.5, color: _muted),
                                ),
                              ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: step.toDouble(),
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayLabel(value.toInt()),
                            style: const TextStyle(fontSize: 10.5, color: _muted),
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: brandRed,
                      barWidth: 2.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: brandRed.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== آخر العمليات =====================

  Widget _recent(bool isDark) {
    final rows = List<Map<String, dynamic>>.from(
        (_data['recent'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    return _card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'آخر العمليات',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _text,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد عمليات', style: TextStyle(color: _muted))),
            )
          else
            for (final r in rows) _recentRow(r, isDark),
        ],
      ),
    );
  }

  Widget _recentRow(Map<String, dynamic> r, bool isDark) {
    final status = (r['status'] ?? '').toString();
    final (String label, Color color) = switch (status) {
      'completed' => ('مكتملة', Colors.green),
      'failed' => ('فاشلة', brandRed),
      'processing' => ('قيد المعالجة', Colors.blue),
      'pending' => ('معلّقة', Colors.orange),
      'cancelled' => ('ملغاة', Colors.grey),
      _ => (status, Colors.grey),
    };
    final type = switch ((r['payment_type'] ?? '').toString()) {
      'wallet_charge' => 'شحن رصيد',
      'custom' => 'دفعة تجريبية',
      final t => t,
    };
    final d = DateTime.tryParse((r['created_at'] ?? '').toString())?.toLocal();
    final date = d == null
        ? ''
        : '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final amount = ((r['total_amount'] as num?) ?? 0).toDouble();
    final reason = r['failure_reason']?.toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (r['store_name'] ?? '—').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : _text,
                  ),
                ),
                Text(
                  [type, date, if (status == 'failed' && reason != null) reason].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _money(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _text,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: TextStyle(fontSize: 11.5, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : _border),
      ),
      child: child,
    );
  }
}
