import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_banner_weeks_screen.dart';

class AdminMerchantBannersScreen extends StatefulWidget {
  const AdminMerchantBannersScreen({super.key});

  @override
  State<AdminMerchantBannersScreen> createState() =>
      _AdminMerchantBannersScreenState();
}

class _AdminMerchantBannersScreenState
    extends State<AdminMerchantBannersScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _filter = 'pending';
  int _tab = 0;

  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

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
    _loadStats();
  }

  /// يجلب إحصاءات البنرات للمنصة
  Future<void> _loadStats() async {
    try {
      final res = await supabase.rpc('get_admin_banner_stats');
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(res as Map);
        _loadingStats = false;
      });
    } catch (e) {
      debugPrint('Admin stats error: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.rpc('get_merchant_banners');
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Merchant banners error: $e');
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

  /// تصنيف البنر
  String _groupOf(Map<String, dynamic> b) {
    if (b['status'] == 'banned') return 'banned';
    if (b['status'] == 'suspended') return 'suspended';
    if (b['is_approved'] == true) return 'approved';
    return 'pending';
  }

  Future<void> _approve(Map<String, dynamic> b) async {
    try {
      final res = await supabase.rpc('approve_banner_booking',
          params: {'p_booking_id': b['id']});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack('اعتُمد البنر', Colors.green);
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الاعتماد', Colors.red);
      }
    } catch (e) {
      debugPrint('Approve error: $e');
      _snack('تعذر تنفيذ العملية', Colors.red);
    }
  }

  /// نافذة الإيقاف مع السبب
  void _suspendDialog(Map<String, dynamic> b) {
    final ctrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.red, size: 19),
                SizedBox(width: 10),
                Text('إيقاف البنر',
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
                    'سيُخفى البنر ويُطلب من ${b['store_name']} تعديله. '
                    'المبلغ يبقى محجوزاً، فإن لم يُعدَّل قبل 24 ساعة من '
                    'بداية الأسبوع أُلغي وأُعيد تلقائياً.',
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
                      hintText:
                          'سبب الإيقاف — يظهر للتاجر في لوحته',
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
                              .rpc('suspend_banner_booking', params: {
                            'p_booking_id': b['id'],
                            'p_reason': ctrl.text.trim(),
                          });
                          final map = Map<String, dynamic>.from(res as Map);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (map['ok'] == true) {
                            await _load();
                            _snack('أُوقف البنر — بانتظار تعديل التاجر',
                                Colors.orange);
                          } else {
                            _snack(map['error']?.toString() ?? 'تعذر الإيقاف',
                                Colors.red);
                          }
                        } catch (e) {
                          debugPrint('Suspend error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر تنفيذ العملية', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري...' : 'إيقاف',
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

  /// نافذة الحظر القطعي
  void _banDialog(Map<String, dynamic> b) {
    final ctrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded,
                    color: Color(0xFFB71C1C), size: 19),
                SizedBox(width: 10),
                Text('حظر البنر',
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
                    ),
                    child: const Text(
                      'الحظر قطعي: لا يُعرض البنر، ولا يُسترد مبلغه، '
                      'ولا يستطيع التاجر تعديله.',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          height: 1.9,
                          color: Color(0xFFB71C1C)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: true,
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13),
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
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
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
                          final res = await supabase
                              .rpc('ban_banner_booking', params: {
                            'p_booking_id': b['id'],
                            'p_reason': ctrl.text.trim(),
                          });
                          final map = Map<String, dynamic>.from(res as Map);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (map['ok'] == true) {
                            await _load();
                            _snack('حُظر البنر نهائياً',
                                const Color(0xFFB71C1C));
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
                child: Text(saving ? 'جاري...' : 'حظر نهائي',
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

  /// معاينة صورة البنر بالحجم الكامل
  void _previewImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      size: 60,
                      color: Colors.white54),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '—';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where((b) => _groupOf(b) == _filter).toList();

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
                  Row(
                    children: [
                      const Text('بنرات التجار',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text('${visible.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'البنرات تُنشر تلقائياً — والمراجعة للإيقاف عند المخالفة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 18),

                  // ===== التبويبات =====
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _mainTab(0, 'المراجعة'),
                      _mainTab(1, 'التقرير'),
                      _mainTab(2, 'إدارة أوقات وأسعار النشر'),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (_tab == 2) ...[
                    const AdminBannerWeeksScreen(),
                  ] else if (_tab == 1) ...[
                    _statsView(),
                  ] else ...[
                  Wrap(
                    spacing: 8,
                    children: _filters.map((f) {
                      final count =
                          _rows.where((b) => _groupOf(b) == f.key).length;
                      final on = _filter == f.key;

                      return GestureDetector(
                        onTap: () => setState(() => _filter = f.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: on ? brandRed : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    on ? brandRed : const Color(0xFFEDEFF3)),
                          ),
                          child: Text(
                            '${f.label} ($count)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight:
                                  on ? FontWeight.bold : FontWeight.normal,
                              color:
                                  on ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (visible.isEmpty)
                    _empty()
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        const gap = 12.0;
                        int cols = 3;
                        if (c.maxWidth < 620) {
                          cols = 1;
                        } else if (c.maxWidth < 1000) {
                          cols = 2;
                        }
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: visible
                              .map((b) =>
                                  SizedBox(width: w, child: _card(b)))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    final group = _groupOf(b);
    final status = (b['status'] ?? '').toString();
    final reason = (b['rejection_reason'] ?? '').toString();
    final occasion = (b['occasion_name'] ?? '').toString();

    final (String label, Color color) = switch (status) {
      'paid' => ('مدفوع — لم يبدأ', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض الآن', Colors.green),
      'suspended' => ('موقوف — بانتظار تعديل التاجر', Colors.orange),
      'banned' => ('محظور', Color(0xFFB71C1C)),
      'expired' => ('انتهى', Colors.grey),
      'cancelled' => ('ألغاه التاجر', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
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
          // ===== الصورة والترويسة =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((b['image_url'] ?? '').toString().isNotEmpty)
                InkWell(
                  onTap: () => _previewImage(b['image_url'].toString()),
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          b['image_url'],
                          width: 110,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 110,
                            height: 58,
                            color: const Color(0xFFF1F2F5),
                            child: const Icon(Icons.image_outlined,
                                size: 18, color: Colors.grey),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_in_rounded,
                            size: 15, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (b['store_name'] ?? 'متجر').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${b['banner_type'] == 'wide' ? 'عريض' : 'صغير'} · '
                      '${b['slots_count']} بنر · '
                      'أسبوع ${b['week_number']} '
                      '(${_fmt(b['week_start'])} — ${_fmt(b['week_end'])})',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                    if (occasion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(occasion,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: brandRed)),
                    ],
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
              Icon(
                b['target_type'] == 'product'
                    ? Icons.inventory_2_outlined
                    : Icons.storefront_outlined,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                b['target_type'] == 'product' ? 'يفتح عرضاً' : 'يفتح المتجر',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Icon(Icons.visibility_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${b['impressions'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const SizedBox(width: 12),
              Icon(Icons.touch_app_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${b['clicks'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const Spacer(),
              Text(
                '${(b['final_price'] as num?)?.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ],
          ),

          // ===== سبب الإيقاف =====
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

          // ===== الأزرار =====
          if (group != 'banned' &&
              (status == 'paid' ||
                  status == 'scheduled' ||
                  status == 'active' ||
                  status == 'suspended')) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (group == 'pending')
                  ElevatedButton.icon(
                    onPressed: () => _approve(b),
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
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                if (status != 'suspended')
                  OutlinedButton.icon(
                    onPressed: () => _suspendDialog(b),
                    icon: const Icon(Icons.pause_circle_outline_rounded,
                        size: 16),
                    label: const Text('إيقاف',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _banDialog(b),
                  icon: const Icon(Icons.gpp_bad_outlined, size: 16),
                  label: const Text('حظر',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB71C1C),
                    side: BorderSide(
                        color: const Color(0xFFB71C1C)
                            .withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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

  // ===================== التقرير =====================

  Widget _statsView() {
    if (_loadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    final st = _stats;
    if (st == null || st['ok'] != true) {
      return _emptyMsg('تعذر تحميل التقرير');
    }

    final revenue = (st['revenue'] as num?)?.toDouble() ?? 0;
    final banners = (st['banners'] as num?)?.toInt() ?? 0;
    final merchants = (st['merchants'] as num?)?.toInt() ?? 0;
    final impressions = (st['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (st['clicks'] as num?)?.toInt() ?? 0;
    final ctr = (st['ctr'] as num?)?.toDouble() ?? 0;
    final wallets = (st['wallets_balance'] as num?)?.toDouble() ?? 0;
    final weeks = (st['weeks'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== البطاقات =====
        LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            int cols = 6;
            if (c.maxWidth < 480) {
              cols = 2;
            } else if (c.maxWidth < 750) {
              cols = 3;
            } else if (c.maxWidth < 1100) {
              cols = 4;
            }
            final w = (c.maxWidth - gap * (cols - 1)) / cols;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                    width: w,
                    child: _statCard('الإيراد',
                        '${revenue.toStringAsFixed(0)} ر.س',
                        Icons.payments_outlined, Colors.green)),
                SizedBox(
                    width: w,
                    child: _statCard('البنرات المباعة', '$banners',
                        Icons.ad_units_outlined, brandRed)),
                SizedBox(
                    width: w,
                    child: _statCard('تجار مشترون', '$merchants',
                        Icons.storefront_outlined, Colors.blue)),
                SizedBox(
                    width: w,
                    child: _statCard('الظهور', '$impressions',
                        Icons.visibility_outlined, Colors.purple)),
                SizedBox(
                    width: w,
                    child: _statCard('النقرات', '$clicks',
                        Icons.touch_app_outlined, Colors.orange)),
                SizedBox(
                    width: w,
                    child: _statCard('معدل النقر', '$ctr%',
                        Icons.percent_rounded, Colors.teal)),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ===== الأرصدة =====
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.amber.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 19, color: Colors.orange),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('أرصدة لم تُستهلك',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      'مبالغ شحنها التجار ولم ينفقوها بعد',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                '${wallets.toStringAsFixed(2)} ر.س',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ===== أداء الأسابيع =====
        const Text('إشغال الأسابيع',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        if (weeks.isEmpty)
          _emptyMsg('لا أسابيع')
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: weeks
                .map((w) => _weekRow(Map<String, dynamic>.from(w)))
                .toList(),
          ),
      ],
    );
  }

  Widget _weekRow(Map<String, dynamic> w) {
    final wideSold = (w['wide_sold'] as num?)?.toInt() ?? 0;
    final wideTotal = (w['wide_total'] as num?)?.toInt() ?? 20;
    final smallSold = (w['small_sold'] as num?)?.toInt() ?? 0;
    final smallTotal = (w['small_total'] as num?)?.toInt() ?? 20;
    final revenue = (w['revenue'] as num?)?.toDouble() ?? 0;
    final occasion = (w['occasion_name'] ?? '').toString();

    final sold = wideSold + smallSold;
    final total = wideTotal + smallTotal;
    final rate = total > 0 ? sold / total : 0.0;

    final Color color = rate >= 0.7
        ? Colors.green
        : rate >= 0.3
            ? Colors.orange
            : Colors.grey;

    return Container(
      width: 150,
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أسبوع ${w['week_number']} · ${w['year']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.bold),
          ),
          Text(
            occasion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: brandRed),
          ),
          const Spacer(),
          Text(
            '${(rate * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F2F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'عريض $wideSold/$wideTotal · صغير $smallSold/$smallTotal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9.5,
                color: Colors.grey.shade600),
          ),
          Text(
            '${revenue.toStringAsFixed(0)} ر.س',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green),
          ),
        ],
      ),
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
                fontSize: 18,
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

  Widget _emptyMsg(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(msg,
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.ad_units_outlined, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            _filter == 'pending'
                ? 'لا بنرات بانتظار المراجعة'
                : _filter == 'approved'
                    ? 'لا بنرات معتمدة'
                    : _filter == 'suspended'
                        ? 'لا بنرات موقوفة'
                        : 'لا بنرات محظورة',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
