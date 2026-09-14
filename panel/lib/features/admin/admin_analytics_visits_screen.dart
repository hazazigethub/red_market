import 'package:flutter/material.dart' as material;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsVisitsScreen extends material.StatefulWidget {
  const AdminAnalyticsVisitsScreen({super.key});

  @override
  material.State<AdminAnalyticsVisitsScreen> createState() =>
      _AdminAnalyticsVisitsScreenState();
}

class _AdminAnalyticsVisitsScreenState
    extends material.State<AdminAnalyticsVisitsScreen> {
  // الافتراضي: آخر 7 أيام
  material.DateTimeRange _selectedRange = material.DateTimeRange(
    start: material.DateUtils.dateOnly(
        DateTime.now().subtract(const Duration(days: 7))),
    end: material.DateUtils.dateOnly(DateTime.now()),
  );

  Future<Map<String, dynamic>> _fetchAdvancedVisitsData() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final todayOnly = material.DateUtils.dateOnly(now);

    try {
      // العدد الحقيقي بلا حد الألف الافتراضي
      final totalCountRes = await supabase
          .from('analytics_visits')
          .count(CountOption.exact);

      // جلب الصفوف على دفعات لتجاوز حد الألف
      final List visitsData = [];
      const int pageSize = 1000;
      int from = 0;
      while (true) {
        final page = await supabase
            .from('analytics_visits')
            .select()
            .order('visited_at', ascending: false)
            .range(from, from + pageSize - 1);

        final rows = page as List;
        visitsData.addAll(rows);
        if (rows.length < pageSize) break;
        from += pageSize;
        if (from > 50000) break; // حد أمان
      }

      final profilesResponse =
          await supabase.from('profiles').select('id, gender');
      final List profilesData = profilesResponse as List;

      // خريطة لجنس المستخدمين لسرعة الوصول
      final Map<String, String> userGenders = {
        for (var item in profilesData)
          item['id'].toString():
              item['gender']?.toString().trim().toLowerCase() ?? 'unknown'
      };

      // تحديد نوع العرض: إذا كان البداية والنهاية نفس اليوم فهو عرض ساعات، غير ذلك أيام
      bool isDailyView =
          !_selectedRange.start.isAtSameMomentAs(_selectedRange.end);

      Map<String, Map<String, int>> dynamicDistribution = {};
      Map<String, Map<String, int>> platformDistribution = {};

      if (isDailyView) {
        // توليد مفاتيح الأيام للنطاق المختار
        int daysCount =
            _selectedRange.end.difference(_selectedRange.start).inDays;
        for (int i = 0; i <= daysCount; i++) {
          String dayLabel = DateFormat('MM/dd')
              .format(_selectedRange.start.add(Duration(days: i)));
          dynamicDistribution[dayLabel] = {'male': 0, 'female': 0};
          platformDistribution[dayLabel] = {'male': 0, 'female': 0};
        }
      } else {
        // توليد 24 ساعة ليوم واحد مختار
        for (int i = 0; i < 24; i++) {
          dynamicDistribution["$i"] = {'male': 0, 'female': 0};
          platformDistribution["$i"] = {'male': 0, 'female': 0};
        }
      }

      int totalVisitsCount = totalCountRes;
      int monthlyVisitsCount = 0;
      int todayVisitsCount = 0;
      int filteredIosCount = 0;
      int filteredAndroidCount = 0;
      int filteredWebCount = 0;
      int filteredMales = 0;
      int filteredFemales = 0;

      for (var v in visitsData) {
        if (v['visited_at'] == null) continue;
        final fullDate = DateTime.parse(v['visited_at']).toLocal();
        final dateOnly = material.DateUtils.dateOnly(fullDate);

        // إحصائيات عامة (خارج الفلتر الزمني المختار)
        if (fullDate.month == now.month && fullDate.year == now.year) {
          monthlyVisitsCount++;
        }
        if (dateOnly.isAtSameMomentAs(todayOnly)) {
          todayVisitsCount++;
        }

        // تطبيق الفلتر الزمني المختار (Selected Range)
        bool isWithinRange = (dateOnly.isAtSameMomentAs(_selectedRange.start) ||
                dateOnly.isAfter(_selectedRange.start)) &&
            (dateOnly.isAtSameMomentAs(_selectedRange.end) ||
                dateOnly.isBefore(_selectedRange.end));

        if (isWithinRange) {
          // حساب المنصات
          String platform = v['platform']?.toString().toLowerCase() ?? '';
          if (platform.contains('ios')) {
            filteredIosCount++;
          } else if (platform.contains('android')) {
            filteredAndroidCount++;
          } else if (platform.contains('web')) {
            filteredWebCount++;
          }

          // حساب الجنس
          final userId = v['user_id']?.toString();
          final g = userGenders[userId] ?? 'unknown';
          bool isFemale = (g == 'female' || g.contains('نث') || g == 'female');

          if (isFemale) {
            filteredFemales++;
          } else {
            filteredMales++;
          }

          // تحديث بيانات المخطط البياني
          String key = isDailyView
              ? DateFormat('MM/dd').format(dateOnly)
              : "${fullDate.hour}";

          if (dynamicDistribution.containsKey(key)) {
            String genderKey = isFemale ? 'female' : 'male';
            dynamicDistribution[key]![genderKey] =
                (dynamicDistribution[key]![genderKey] ?? 0) + 1;
          }

          // توزيع المنصات — male للتطبيق · female للموقع
          if (platformDistribution.containsKey(key)) {
            final isWeb = platform.contains('web');
            final pKey = isWeb ? 'female' : 'male';
            platformDistribution[key]![pKey] =
                (platformDistribution[key]![pKey] ?? 0) + 1;
          }
        }
      }

      return {
        'total': totalVisitsCount,
        'monthly': monthlyVisitsCount,
        'today': todayVisitsCount,
        'chartData': dynamicDistribution,
        'platformChart': platformDistribution,
        'isDailyView': isDailyView,
        'ios': filteredIosCount,
        'android': filteredAndroidCount,
        'web': filteredWebCount,
        'totalMales': filteredMales,
        'totalFemales': filteredFemales,
      };
    } catch (e) {
      material.debugPrint("Error fetching analytics: $e");
      throw "حدث خطأ أثناء معالجة البيانات: $e";
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    const material.Color brandRed = material.Color(0xFFD32027);

    return material.Directionality(
      textDirection: material.TextDirection.rtl,
      child: material.Scaffold(
        backgroundColor: const material.Color(0xFFF7F8FA),
                body: material.FutureBuilder<Map<String, dynamic>>(
          future: _fetchAdvancedVisitsData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == material.ConnectionState.waiting) {
              return const material.Center(
                  child: material.CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return material.Center(
                  child: material.Text("⚠️ ${snapshot.error}"));
            }

            final s = snapshot.data!;
            final chartDataMap =
                s['chartData'] as Map<String, Map<String, int>>;
            final bool isDailyView = s['isDailyView'];

            return material.SingleChildScrollView(
              padding:
                  const material.EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: material.Center(
                child: material.ConstrainedBox(
                  constraints: const material.BoxConstraints(maxWidth: 1050),
                  child: material.Column(
                crossAxisAlignment: material.CrossAxisAlignment.start,
                children: [
                  const material.Text('الزيارات',
                      style: material.TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: material.FontWeight.bold)),
                  const material.SizedBox(height: 6),
                  material.Text(
                    'حركة الزوار عبر المنصات والفترات الزمنية',
                    style: material.TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: material.Colors.grey.shade500),
                  ),
                  const material.SizedBox(height: 20),
                  material.Row(
                    children: [
                      _buildTappableSmallCard(
                          "إجمالي الزيارات",
                          "${s['total']}",
                          material.Colors.blue,
                          material.Icons.public, () {}),
                      const material.SizedBox(width: 10),
                      _buildTappableSmallCard(
                          "زيارات الشهر",
                          "${s['monthly']}",
                          material.Colors.orange,
                          material.Icons.calendar_month, () {
                        final now = DateTime.now();
                        setState(() {
                          _selectedRange = material.DateTimeRange(
                            start: DateTime(now.year, now.month, 1),
                            end: material.DateUtils.dateOnly(now),
                          );
                        });
                      }),
                      const material.SizedBox(width: 10),
                      _buildTappableSmallCard("زيارات اليوم", "${s['today']}",
                          material.Colors.green, material.Icons.today, () {
                        final now = material.DateUtils.dateOnly(DateTime.now());
                        setState(() {
                          _selectedRange =
                              material.DateTimeRange(start: now, end: now);
                        });
                      }),
                      const material.SizedBox(width: 10),
                      _buildCalendarCard(context, _selectedRange,
                          (material.DateTimeRange newRange) {
                        setState(() {
                          _selectedRange = material.DateTimeRange(
                            start: material.DateUtils.dateOnly(newRange.start),
                            end: material.DateUtils.dateOnly(newRange.end),
                          );
                        });
                      }),
                    ],
                  ),
                  const material.SizedBox(height: 30),
                  material.Text(
                      !isDailyView
                          ? "تحليل ساعات يوم: ${DateFormat('yyyy/MM/dd').format(_selectedRange.start)}"
                          : "تحليل الفترة من ${DateFormat('MM/dd').format(_selectedRange.start)} إلى ${DateFormat('MM/dd').format(_selectedRange.end)}",
                      style: const material.TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: material.FontWeight.bold,
                          fontSize: 14)),
                  const material.SizedBox(height: 15),
                  _buildAestheticChart(chartDataMap, isDailyView),
                  _buildLegend(s['totalMales'], s['totalFemales']),

                  const material.SizedBox(height: 30),

                  // ===== مخطط المنصات =====
                  const material.Text("الزيارات حسب المنصة",
                      style: material.TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: material.FontWeight.bold,
                          fontSize: 14)),
                  const material.SizedBox(height: 15),
                  _buildAestheticChart(
                    (s['platformChart'] as Map<String, Map<String, int>>?) ??
                        {},
                    isDailyView,
                  ),
                  _buildPlatformLegend(
                      (s['android'] as int) + (s['ios'] as int),
                      s['web'] as int),

                  const material.SizedBox(height: 30),
                  const material.Text("توزيع المنصات في الفترة المحددة",
                      style: material.TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: material.FontWeight.bold,
                          fontSize: 16)),
                  const material.SizedBox(height: 12),
                  material.Row(
                    children: [
                      _buildStaticSmallCard(
                          "Android",
                          "${s['android']}",
                          material.Colors.green.shade700,
                          material.Icons.android),
                      const material.SizedBox(width: 10),
                      _buildStaticSmallCard("iOS", "${s['ios']}",
                          material.Colors.grey.shade800, material.Icons.apple),
                      const material.SizedBox(width: 10),
                      _buildStaticSmallCard(
                          "الموقع",
                          "${s['web']}",
                          material.Colors.blue.shade700,
                          material.Icons.language_rounded),
                    ],
                  ),
                ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- أدوات بناء الواجهة ---

  material.Widget _buildTappableSmallCard(
      String label,
      String value,
      material.Color color,
      material.IconData icon,
      material.VoidCallback onTap) {
    return material.Expanded(
      child: material.InkWell(
        onTap: onTap,
        borderRadius: material.BorderRadius.circular(14),
        child: material.Container(
          height: 108,
          padding: const material.EdgeInsets.all(12),
          decoration: material.BoxDecoration(
              color: material.Colors.white,
              borderRadius: material.BorderRadius.circular(14),
              border: material.Border.all(
                  color: const material.Color(0xFFEDEFF3))),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              material.Row(
                children: [
                  material.Icon(icon, color: color, size: 17),
                  const material.SizedBox(width: 8),
                  material.Expanded(
                    child: material.Text(label,
                        maxLines: 1,
                        overflow: material.TextOverflow.ellipsis,
                        style: material.TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: material.Colors.grey.shade600)),
                  ),
                ],
              ),
              const material.Spacer(),
              material.Text(value,
                  style: material.TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: material.FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  material.Widget _buildStaticSmallCard(String label, String value,
      material.Color color, material.IconData icon) {
    return material.Expanded(
      child: material.Container(
        height: 108,
        padding: const material.EdgeInsets.all(12),
        decoration: material.BoxDecoration(
            color: material.Colors.white,
            borderRadius: material.BorderRadius.circular(14),
            border: material.Border.all(
                color: const material.Color(0xFFEDEFF3))),
        child: material.Column(
          crossAxisAlignment: material.CrossAxisAlignment.start,
          children: [
            material.Row(
              children: [
                material.Icon(icon, color: color, size: 17),
                const material.SizedBox(width: 8),
                material.Expanded(
                  child: material.Text(label,
                      maxLines: 1,
                      overflow: material.TextOverflow.ellipsis,
                      style: material.TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: material.Colors.grey.shade600)),
                ),
              ],
            ),
            const material.Spacer(),
            material.Text(value,
                style: material.TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: material.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  material.Widget _buildCalendarCard(
      material.BuildContext context,
      material.DateTimeRange selectedRange,
      void Function(material.DateTimeRange) onRangeSelected) {
    return material.Expanded(
      child: material.InkWell(
        onTap: () async {
          final DateTime today = material.DateUtils.dateOnly(DateTime.now());
          final picked = await material.showDateRangePicker(
            context: context,
            initialDateRange: selectedRange,
            firstDate: DateTime(2024),
            lastDate: today,
            saveText: "اعتماد",
          );
          if (picked != null) onRangeSelected(picked);
        },
        borderRadius: material.BorderRadius.circular(14),
        child: material.Container(
          height: 108,
          padding: const material.EdgeInsets.all(12),
          decoration: material.BoxDecoration(
            color: material.Colors.white,
            borderRadius: material.BorderRadius.circular(14),
            border: material.Border.all(
                color: const material.Color(0xFFEDEFF3)),
          ),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              material.Row(
                children: [
                  const material.Icon(material.Icons.date_range,
                      size: 17, color: material.Colors.orange),
                  const material.SizedBox(width: 8),
                  material.Expanded(
                    child: material.Text('تاريخ مخصص',
                        maxLines: 1,
                        overflow: material.TextOverflow.ellipsis,
                        style: material.TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: material.Colors.grey.shade600)),
                  ),
                ],
              ),
              const material.Spacer(),
              material.FittedBox(
                child: material.Text(
                  "${DateFormat('MM/dd').format(selectedRange.start)} - ${DateFormat('MM/dd').format(selectedRange.end)}",
                  style: const material.TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: material.FontWeight.bold,
                      color: material.Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  material.Widget _buildAestheticChart(
      Map<String, Map<String, int>> data, bool isDaily) {
    return material.Container(
      height: 260,
      width: double.infinity,
      decoration: material.BoxDecoration(
        color: material.Colors.white,
        borderRadius: material.BorderRadius.circular(16),
        border:
            material.Border.all(color: const material.Color(0xFFEDEFF3)),
      ),
      child: material.SingleChildScrollView(
        scrollDirection: material.Axis.horizontal,
        physics: const material.BouncingScrollPhysics(),
        child: material.Padding(
          padding: const material.EdgeInsets.only(top: 20),
          child: material.CustomPaint(
            size: material.Size(data.length * 60.0 + 40, 200),
            painter: _ModernPathPainter(statsMap: data, isDaily: isDaily),
          ),
        ),
      ),
    );
  }

  material.Widget _buildLegend(int maleCount, int femaleCount) {
    return material.Padding(
      padding: const material.EdgeInsets.only(top: 20),
      child: material.Row(
          mainAxisAlignment: material.MainAxisAlignment.center,
          children: [
            _dot(material.Colors.blue.shade400, "ذكر", maleCount),
            const material.SizedBox(width: 30),
            _dot(material.Colors.pink.shade300, "أنثى", femaleCount),
          ]),
    );
  }

  material.Widget _buildPlatformLegend(int appCount, int webCount) {
    return material.Padding(
      padding: const material.EdgeInsets.only(top: 20),
      child: material.Row(
          mainAxisAlignment: material.MainAxisAlignment.center,
          children: [
            _dot(material.Colors.blue.shade400, "التطبيق", appCount),
            const material.SizedBox(width: 30),
            _dot(material.Colors.pink.shade300, "الموقع", webCount),
          ]),
    );
  }

  material.Widget _dot(material.Color c, String t, int count) =>
      material.Row(children: [
        material.Container(
            width: 12,
            height: 12,
            decoration: material.BoxDecoration(
                color: c, shape: material.BoxShape.circle)),
        const material.SizedBox(width: 8),
        material.Text("$t: $count",
            style: const material.TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: material.FontWeight.bold))
      ]);
}

class _ModernPathPainter extends material.CustomPainter {
  final Map<String, Map<String, int>> statsMap;
  final bool isDaily;
  _ModernPathPainter({required this.statsMap, required this.isDaily});

  @override
  void paint(material.Canvas canvas, material.Size size) {
    final List<Map<String, int>> stats = statsMap.values.toList();
    final List<String> labels = statsMap.keys.toList();
    const double stepX = 60.0;

    int maxV = 5;
    for (var s in stats) {
      if (s['male']! > maxV) maxV = s['male']!;
      if (s['female']! > maxV) maxV = s['female']!;
    }

    final double scaleY = (size.height - 80) / maxV;
    final material.Paint maleLine = material.Paint()
      ..color = material.Colors.blue.shade400
      ..style = material.PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = material.StrokeCap.round;
    final material.Paint femaleLine = material.Paint()
      ..color = material.Colors.pink.shade300
      ..style = material.PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = material.StrokeCap.round;

    final material.Path mPath = material.Path();
    final material.Path fPath = material.Path();

    for (int i = 0; i < stats.length; i++) {
      final double x = i * stepX + 40;
      final double yM = size.height - 60 - (stats[i]['male']! * scaleY);
      final double yF = size.height - 60 - (stats[i]['female']! * scaleY);

      if (i == 0) {
        mPath.moveTo(x, yM);
        fPath.moveTo(x, yF);
      } else {
        final double prevX = (i - 1) * stepX + 40;
        final double prevYM =
            size.height - 60 - (stats[i - 1]['male']! * scaleY);
        final double prevYF =
            size.height - 60 - (stats[i - 1]['female']! * scaleY);

        mPath.cubicTo((prevX + x) / 2, prevYM, (prevX + x) / 2, yM, x, yM);
        fPath.cubicTo((prevX + x) / 2, prevYF, (prevX + x) / 2, yF, x, yF);
      }

      // رسم النقاط والقيم
      if (stats[i]['male']! > 0) {
        _drawText(canvas, "${stats[i]['male']}", material.Offset(x, yM - 22),
            material.Colors.blue.shade700);
      }
      if (stats[i]['female']! > 0) {
        _drawText(canvas, "${stats[i]['female']}", material.Offset(x, yF + 8),
            material.Colors.pink.shade700);
      }

      // رسم التسميات التوضيحية (X-Axis)
      String labelText = isDaily ? labels[i] : "${labels[i]}h";
      _drawText(canvas, labelText, material.Offset(x, size.height - 25),
          material.Colors.grey.shade500,
          fontSize: 10);
    }

    canvas.drawPath(mPath, maleLine);
    canvas.drawPath(fPath, femaleLine);
  }

  void _drawText(material.Canvas canvas, String text, material.Offset offset,
      material.Color color,
      {double fontSize = 11}) {
    final textPainter = material.TextPainter(
      text: material.TextSpan(
          text: text,
          style: material.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: material.FontWeight.bold,
              fontFamily: 'Cairo')),
      textDirection: material.TextDirection.rtl,
    )..layout();
    textPainter.paint(
        canvas, material.Offset(offset.dx - textPainter.width / 2, offset.dy));
  }

  @override
  bool shouldRepaint(covariant material.CustomPainter oldDelegate) => true;
}
