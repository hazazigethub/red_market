import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إدارة إعلان الشاشة الرئيسية — الأيام والمراجعة
class AdminSplashAdsScreen extends StatefulWidget {
  const AdminSplashAdsScreen({super.key});

  @override
  State<AdminSplashAdsScreen> createState() => _AdminSplashAdsScreenState();
}

class _AdminSplashAdsScreenState extends State<AdminSplashAdsScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _days = [];
  List<Map<String, dynamic>> _ads = [];
  bool _loading = true;
  bool _generating = false;

  int _tab = 0;
  String _filter = 'pending';

  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _revenue;
  bool _loadingRevenue = true;

  static const _filters = [
    (key: 'pending', label: 'لم تُراجع'),
    (key: 'approved', label: 'معتمدة'),
    (key: 'suspended', label: 'موقوفة'),
    (key: 'banned', label: 'محظورة'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadRevenue();
  }

  /// يجلب التقرير المالي
  Future<void> _loadRevenue() async {
    try {
      final res = await supabase.rpc('get_ads_revenue_report');
      if (!mounted) return;
      setState(() {
        _revenue = Map<String, dynamic>.from(res as Map);
        _loadingRevenue = false;
      });
    } catch (e) {
      debugPrint('Revenue error: $e');
      if (mounted) setState(() => _loadingRevenue = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final days = await supabase
          .from('splash_ad_days')
          .select()
          .gte('ad_date', DateTime.now().toIso8601String().substring(0, 10))
          .order('ad_date');

      final ads = await supabase
          .from('splash_ads')
          .select()
          .order('ad_date', ascending: false);

      final list = List<Map<String, dynamic>>.from(ads);

      // أسماء المتاجر — بجلب منفصل، فلا علاقة مباشرة بين الجدولين
      final ids = list
          .map((a) => a['merchant_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final merch = await supabase
            .from('merchants')
            .select('id, store_name')
            .inFilter('id', ids);

        for (final m in List<Map<String, dynamic>>.from(merch)) {
          names[m['id'].toString()] =
              (m['store_name'] ?? 'متجر').toString();
        }
      }

      for (final a in list) {
        a['store_name'] = names[a['merchant_id']?.toString()] ?? 'متجر';
      }

      if (!mounted) return;
      setState(() {
        _days = List<Map<String, dynamic>>.from(days);
        _ads = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Splash admin error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final res = await supabase
          .rpc('generate_splash_days', params: {'p_count': 30});
      await _load();
      _snack('أُضيف ${res ?? 30} يوماً', Colors.green);
    } catch (e) {
      debugPrint('Generate error: $e');
      _snack('تعذر التوليد', Colors.red);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// نافذة تعديل اليوم
  void _editDay(Map<String, dynamic> d) {
    final price = TextEditingController(
        text: '${(d['price'] as num?)?.toInt() ?? 0}');
    final occasion =
        TextEditingController(text: (d['occasion_name'] ?? '').toString());
    bool isOpen = d['is_open'] == true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.event_rounded,
                      color: brandRed, size: 17),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    (d['ad_date'] ?? '').toString(),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
                    decoration: _dec('سعر اليوم', Icons.payments_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: occasion,
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
                    decoration:
                        _dec('اسم المناسبة', Icons.celebration_outlined),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isOpen,
                    activeColor: brandRed,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('الحجز مفتوح',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold)),
                    onChanged: (v) => setModal(() => isOpen = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        setModal(() => saving = true);
                        try {
                          await supabase.from('splash_ad_days').update({
                            'price': int.tryParse(price.text.trim()) ?? 0,
                            'occasion_name': occasion.text.trim().isEmpty
                                ? null
                                : occasion.text.trim(),
                            'is_open': isOpen,
                          }).eq('ad_date', d['ad_date']);

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          _snack('حُفظ اليوم', Colors.green);
                        } catch (e) {
                          debugPrint('Save error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر الحفظ', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري الحفظ...' : 'حفظ',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
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
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // ===================== المراجعة =====================

  String _groupOf(Map<String, dynamic> a) {
    if (a['status'] == 'banned') return 'banned';
    if (a['status'] == 'suspended') return 'suspended';
    if (a['is_approved'] == true) return 'approved';
    return 'pending';
  }

  Future<void> _approve(Map<String, dynamic> a) async {
    try {
      await supabase.from('splash_ads').update({
        'is_approved': true,
        'rejection_reason': null,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', a['id']);

      await _load();
      _snack('اعتُمد الإعلان', Colors.green);
    } catch (e) {
      debugPrint('Approve error: $e');
      _snack('تعذر الاعتماد', Colors.red);
    }
  }

  void _suspendDialog(Map<String, dynamic> a) {
    final ctrl = TextEditingController();
    bool saving = false;

    final store = (a['store_name'] ?? 'المتجر').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.red, size: 19),
                SizedBox(width: 10),
                Text('إيقاف الإعلان',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سيُوقف الإعلان ويصل $store إشعار بالسبب. '
                    'يمكنه تعديل الصورة قبل 24 ساعة من موعد العرض '
                    'فيعود للمراجعة، وإلا أُلغي تلقائياً وأُعيد المبلغ لرصيده.',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, height: 1.9),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: true,
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'سبب الإيقاف — يظهر للتاجر في لوحته',
                      hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (ctrl.text.trim().isEmpty) {
                          _snack('اكتب سبب الإيقاف', Colors.orange);
                          return;
                        }
                        setModal(() => saving = true);

                        try {
                          final res = await supabase
                              .rpc('suspend_splash_ad', params: {
                            'p_ad_id': a['id'],
                            'p_reason': ctrl.text.trim(),
                          });
                          final map = Map<String, dynamic>.from(res as Map);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (map['ok'] == true) {
                            await _load();
                            _snack('أُوقف الإعلان — بانتظار تعديل التاجر',
                                Colors.orange);
                          } else {
                            _snack(
                                map['error']?.toString() ?? 'تعذر الإيقاف',
                                Colors.red);
                          }
                        } catch (e) {
                          debugPrint('Suspend error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر تنفيذ العملية', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري...' : 'إيقاف الإعلان',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// نافذة الحظر — قطعي وبلا استرداد
  void _banDialog(Map<String, dynamic> a) {
    final ctrl = TextEditingController();
    bool saving = false;

    final store = (a['store_name'] ?? 'المتجر').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 20),
                SizedBox(width: 10),
                Text('حظر الإعلان',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'الحظر قطعي:\n'
                      '• لا يُعرض الإعلان\n'
                      '• لا يُسترد المبلغ\n'
                      '• لا يستطيع التاجر تعديله',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 2.0,
                          color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'يصل $store إشعار بالسبب.',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 12.5, height: 1.8),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: true,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'سبب الحظر — يظهر للتاجر',
                      hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (ctrl.text.trim().isEmpty) {
                          _snack('اكتب سبب الحظر', Colors.orange);
                          return;
                        }
                        setModal(() => saving = true);

                        try {
                          final res =
                              await supabase.rpc('ban_splash_ad', params: {
                            'p_ad_id': a['id'],
                            'p_reason': ctrl.text.trim(),
                          });
                          final map = Map<String, dynamic>.from(res as Map);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (map['ok'] == true) {
                            await _load();
                            _snack('حُظر الإعلان', Colors.red);
                          } else {
                            _snack(map['error']?.toString() ?? 'تعذر الحظر',
                                Colors.red);
                          }
                        } catch (e) {
                          debugPrint('Ban error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر تنفيذ العملية', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري...' : 'تأكيد الحظر',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// معاينة الإعلان بالحجم الكامل
  void _previewAd(Map<String, dynamic> a) {
    final url = (a['image_url'] ?? '').toString();
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 300,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('تعذر عرض الصورة',
                            style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
                label: const Text('إغلاق',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== البناء =====================

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
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إعلان الشاشة الرئيسية',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'موضع واحد حصري لكل يوم — والحجز يبدأ بعد ثلاثة أيام',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 8,
                    children: [
                      _mainTab(0, 'الأيام والأسعار'),
                      _mainTab(1, 'المراجعة'),
                      _mainTab(2, 'التقرير المالي'),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_tab == 0)
                    _daysView()
                  else if (_tab == 1)
                    _reviewView()
                  else
                    _revenueView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainTab(int index, String label) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? brandRed : const Color(0xFFEDEFF3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
            color: on ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ===== الأيام — تقويم شهري =====

  Widget _daysView() {
    final taken = <String>{
      for (final a in _ads)
        if (['paid', 'scheduled', 'active'].contains(a['status']))
          (a['ad_date'] ?? '').toString()
    };

    const names = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    final first = DateTime(_calMonth.year, _calMonth.month, 1);
    final daysInMonth = DateTime(_calMonth.year, _calMonth.month + 1, 0).day;
    final lead = first.weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${_days.length} يوماً مولّداً',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    color: Colors.grey.shade600)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_generating ? 'جاري...' : 'توليد 30 يوماً',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

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
                  _calMonth = DateTime(_calMonth.year, _calMonth.month - 1);
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
                  _calMonth = DateTime(_calMonth.year, _calMonth.month + 1);
                }),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.85,
          ),
          itemCount: lead + daysInMonth,
          itemBuilder: (context, i) {
            if (i < lead) return const SizedBox.shrink();
            final day =
                DateTime(_calMonth.year, _calMonth.month, i - lead + 1);
            return _dayCell(day, taken);
          },
        ),

        const SizedBox(height: 16),

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
          'اضغط أي يوم لتعديل سعره أو مناسبته أو إغلاقه',
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade500),
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

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Widget _dayCell(DateTime day, Set<String> taken) {
    final key = _dateKey(day);

    final info = _days.cast<Map<String, dynamic>?>().firstWhere(
          (d) => (d?['ad_date'] ?? '').toString().startsWith(key),
          orElse: () => null,
        );

    if (info == null) {
      return _cellBox(
        day.day,
        fill: const Color(0xFFFAFAFA),
        border: const Color(0xFFF1F2F5),
        textColor: Colors.grey.shade300,
      );
    }

    final isTaken = taken.any((t) => t.startsWith(key));
    final open = info['is_open'] == true;
    final price = (info['price'] as num?)?.toInt() ?? 0;
    final occasion = (info['occasion_name'] ?? '').toString();

    return InkWell(
      onTap: () => _editDay(info),
      borderRadius: BorderRadius.circular(9),
      child: _cellBox(
        day.day,
        fill: isTaken
            ? brandRed.withValues(alpha: 0.1)
            : open
                ? Colors.white
                : const Color(0xFFF1F2F5),
        border: isTaken
            ? brandRed.withValues(alpha: 0.5)
            : occasion.isNotEmpty
                ? brandRed.withValues(alpha: 0.4)
                : open
                    ? const Color(0xFFD5D8DE)
                    : const Color(0xFFE5E7EB),
        textColor: isTaken
            ? brandRed
            : open
                ? const Color(0xFF1F2937)
                : Colors.grey.shade400,
        label: isTaken ? 'محجوز' : '$price',
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
          Text('$day',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 8.5, color: textColor)),
          ],
        ],
      ),
    );
  }

  // ===== المراجعة =====

  Widget _reviewView() {
    final visible = _ads.where((a) => _groupOf(a) == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: _filters.map((f) {
            final count = _ads.where((a) => _groupOf(a) == f.key).length;
            final on = _filter == f.key;

            return GestureDetector(
              onTap: () => setState(() => _filter = f.key),
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
                  '${f.label} ($count)',
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

        const SizedBox(height: 16),

        if (visible.isEmpty)
          _emptyMsg(switch (_filter) {
            'pending' => 'لا إعلانات بانتظار المراجعة',
            'approved' => 'لا إعلانات معتمدة',
            'suspended' => 'لا إعلانات موقوفة',
            _ => 'لا إعلانات محظورة',
          })
        else
          ...visible.map(_adCard),
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> a) {
    final group = _groupOf(a);
    final status = (a['status'] ?? '').toString();
    final reason = (a['rejection_reason'] ?? '').toString();
    final store = (a['store_name'] ?? 'متجر').toString();

    final (String label, Color color) = switch (status) {
      'paid' => ('مدفوع', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض اليوم', Colors.green),
      'suspended' => ('موقوف — بانتظار التعديل', Colors.orange),
      'banned' => ('محظور', Color(0xFFB71C1C)),
      'expired' => ('انتهى', Colors.grey),
      'cancelled' => ('ملغى', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: group == 'pending'
              ? Colors.orange.withValues(alpha: 0.35)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((a['image_url'] ?? '').toString().isNotEmpty)
                InkWell(
                  onTap: () => _previewAd(a),
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          a['image_url'],
                          width: 52,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 52,
                            height: 88,
                            color: const Color(0xFFF1F2F5),
                            child: const Icon(Icons.image_outlined,
                                size: 17, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(Icons.zoom_in_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      'يوم ${a['ad_date']}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          a['target_type'] == 'product'
                              ? Icons.inventory_2_outlined
                              : Icons.storefront_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          a['target_type'] == 'product'
                              ? 'يفتح عرضاً'
                              : 'يفتح المتجر',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade600),
                        ),
                      ],
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
                '${(a['final_price'] as num?)?.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: Colors.red),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(reason,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            height: 1.8,
                            color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],

          if (group != 'banned' &&
              ['paid', 'scheduled', 'active', 'suspended']
                  .contains(status)) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (group == 'pending')
                  ElevatedButton.icon(
                    onPressed: () => _approve(a),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('اعتماد',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                if (group != 'suspended')
                  OutlinedButton.icon(
                    onPressed: () => _suspendDialog(a),
                    icon: const Icon(Icons.pause_circle_outline_rounded,
                        size: 16),
                    label: const Text('إيقاف حتى التعديل',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                OutlinedButton.icon(
                  onPressed: () => _banDialog(a),
                  icon: const Icon(Icons.gpp_bad_rounded, size: 16),
                  label: const Text('حظر',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade900,
                    side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _revenueView() {
    if (_loadingRevenue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    final r = _revenue;
    if (r == null || r['ok'] != true) {
      return _emptyMsg('تعذر تحميل التقرير');
    }

    final banners = Map<String, dynamic>.from(r['banners'] as Map);
    final splash = Map<String, dynamic>.from(r['splash'] as Map);

    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== الإجمالي =====
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [brandRed, Color(0xFF8E1010)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إيراد الإعلانات',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    n(r['grand_total']).toStringAsFixed(2),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text('ر.س',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _whiteBox('محقّق', n(r['grand_earned'])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _whiteBox('تحت التنفيذ', n(r['grand_pending'])),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.undo_rounded,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 7),
                  Text(
                    'مستردّ للتجار ${n(r['grand_refunded']).toStringAsFixed(2)} ر.س',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ===== التفصيل =====
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 700;
            final cards = [
              _sourceCard('البنرات الأسبوعية',
                  Icons.view_carousel_outlined, banners, n),
              _sourceCard('إعلان الشاشة الرئيسية',
                  Icons.smartphone_outlined, splash, n),
            ];

            if (!wide) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 12),
                  cards[1],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'المحقّق: إعلانات انتهى عرضها أو حُظرت — إيراد نهائي.\n'
                  'تحت التنفيذ: مباعة ولم تُعرض بعد — قد تُلغى ويُسترد مبلغها.',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      height: 1.9,
                      color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _whiteBox(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: Colors.white70)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(2)} ر.س',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _sourceCard(String title, IconData icon,
      Map<String, dynamic> data, double Function(dynamic) n) {
    return Container(
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
              Icon(icon, size: 18, color: brandRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _revLine('محقّق', n(data['earned']), Colors.green),
          const SizedBox(height: 9),
          _revLine('تحت التنفيذ', n(data['pending']), Colors.blue),
          const SizedBox(height: 9),
          _revLine('مستردّ', n(data['refunded']), Colors.grey),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(color: Color(0xFFEDEFF3), height: 1),
          ),
          Row(
            children: [
              const Text('الإجمالي',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${n(data['total']).toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: brandRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revLine(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text('${value.toStringAsFixed(2)} ر.س',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _emptyMsg(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.smartphone_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(msg,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
