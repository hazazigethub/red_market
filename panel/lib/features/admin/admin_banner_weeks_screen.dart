import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminBannerWeeksScreen extends StatefulWidget {
  const AdminBannerWeeksScreen({super.key});

  @override
  State<AdminBannerWeeksScreen> createState() =>
      _AdminBannerWeeksScreenState();
}

class _AdminBannerWeeksScreenState extends State<AdminBannerWeeksScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _weeks = [];
  final Map<String, int> _bookedWide = {};
  final Map<String, int> _bookedSmall = {};

  bool _loading = true;
  bool _generating = false;
  bool _hidePast = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final weeks = await supabase
          .from('banner_weeks')
          .select()
          .order('week_start');

      final bookings = await supabase
          .from('banner_bookings')
          .select('week_id, banner_type, slots_count, status')
          .inFilter('status', ['paid', 'scheduled', 'active']);

      _bookedWide.clear();
      _bookedSmall.clear();

      for (final b in List<Map<String, dynamic>>.from(bookings)) {
        final wid = b['week_id'].toString();
        final n = (b['slots_count'] as num?)?.toInt() ?? 0;
        if (b['banner_type'] == 'wide') {
          _bookedWide[wid] = (_bookedWide[wid] ?? 0) + n;
        } else {
          _bookedSmall[wid] = (_bookedSmall[wid] ?? 0) + n;
        }
      }

      if (mounted) {
        setState(() {
          _weeks = List<Map<String, dynamic>>.from(weeks);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Weeks load error: $e');
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
      final res =
          await supabase.rpc('generate_banner_weeks', params: {'p_count': 4});
      await _load();
      _snack('أُضيفت ${res ?? 4} أسابيع', Colors.green);
    } catch (e) {
      debugPrint('Generate error: $e');
      _snack('تعذر التوليد', Colors.red);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// نافذة تعديل الأسبوع
  void _editDialog(Map<String, dynamic> w) {
    final occasion =
        TextEditingController(text: (w['occasion_name'] ?? '').toString());
    final priceWide = TextEditingController(
        text: '${(w['price_wide'] as num?)?.toInt() ?? 0}');
    final priceSmall = TextEditingController(
        text: '${(w['price_small'] as num?)?.toInt() ?? 0}');
    bool isOpen = w['is_open'] == true;
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
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: brandRed, size: 17),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'الأسبوع ${w['week_number']} · ${w['year']} — '
                    '${_fmt(w['week_start'])} إلى ${_fmt(w['week_end'])}',
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
                  _field(
                    controller: occasion,
                    label: 'اسم المناسبة',
                    hint: 'اليوم الوطني · الجمعة البيضاء',
                    icon: Icons.celebration_outlined,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: priceWide,
                    label: 'سعر البنر العريض',
                    hint: '0',
                    icon: Icons.crop_16_9_rounded,
                    numeric: true,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: priceSmall,
                    label: 'سعر البنر الصغير',
                    hint: '0',
                    icon: Icons.crop_square_rounded,
                    numeric: true,
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
                    subtitle: Text(
                        isOpen
                            ? 'يستطيع التجار الحجز في هذا الأسبوع'
                            : 'الحجز مغلق — لا يظهر للتجار',
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 11.5)),
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
                          await supabase.from('banner_weeks').update({
                            'occasion_name': occasion.text.trim().isEmpty
                                ? null
                                : occasion.text.trim(),
                            'price_wide':
                                int.tryParse(priceWide.text.trim()) ?? 0,
                            'price_small':
                                int.tryParse(priceSmall.text.trim()) ?? 0,
                            'is_open': isOpen,
                          }).eq('id', w['id']);

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          _snack('حُفظ الأسبوع', Colors.green);
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : null,
      inputFormatters:
          numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade400),
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
      ),
    );
  }

  bool _isPast(Map<String, dynamic> w) {
    final end = DateTime.tryParse((w['week_end'] ?? '').toString());
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String _fmt(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '—';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _hidePast ? _weeks.where((w) => !_isPast(w)).toList() : _weeks;

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
                  // ===== الترويسة =====
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const Text('الأسابيع الإعلانية',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      Text('${visible.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _hidePast = !_hidePast),
                        icon: Icon(
                            _hidePast
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 17),
                        label: Text(
                            _hidePast ? 'إظهار المنقضية' : 'إخفاء المنقضية',
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _generating ? null : _generate,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                            _generating ? 'جاري...' : 'توليد 4 أسابيع',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

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
                        const gap = 14.0;
                        int cols = 6;
                        if (c.maxWidth < 480) {
                          cols = 2;
                        } else if (c.maxWidth < 700) {
                          cols = 3;
                        } else if (c.maxWidth < 950) {
                          cols = 4;
                        } else if (c.maxWidth < 1250) {
                          cols = 5;
                        }

                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: visible
                              .map((week) =>
                                  SizedBox(width: w, child: _card(week)))
                              .toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> w) {
    final id = w['id'].toString();
    final past = _isPast(w);
    final open = w['is_open'] == true;

    final wide = _bookedWide[id] ?? 0;
    final small = _bookedSmall[id] ?? 0;
    final wideTotal = (w['wide_slots_total'] as num?)?.toInt() ?? 20;
    final smallTotal = (w['small_slots_total'] as num?)?.toInt() ?? 20;

    final occasion = (w['occasion_name'] ?? '').toString();

    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: past ? const Color(0xFFF7F8FA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: past
                ? const Color(0xFFEDEFF3)
                : occasion.isNotEmpty
                    ? brandRed.withValues(alpha: 0.35)
                    : const Color(0xFFEDEFF3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== الترويسة =====
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: past
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
                      color: past ? Colors.grey : brandRed,
                    ),
                  ),
                ),
                const Spacer(),
                if (!past)
                  InkWell(
                    onTap: () => _editDialog(w),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(Icons.edit_outlined,
                          size: 17, color: Colors.grey.shade600),
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
                color: past ? Colors.grey : const Color(0xFF1F2937),
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
                color: occasion.isEmpty
                    ? Colors.grey.shade400
                    : brandRed,
              ),
            ),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFEDEFF3), height: 1),
            const SizedBox(height: 12),

            // ===== الأسعار =====
            _priceRow('عريض', w['price_wide'], wide, wideTotal, past),
            const SizedBox(height: 8),
            _priceRow('صغير', w['price_small'], small, smallTotal, past),

            const SizedBox(height: 12),

            // ===== الحالة =====
            Row(
              children: [
                Icon(
                  past
                      ? Icons.history_rounded
                      : open
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                  size: 14,
                  color: past
                      ? Colors.grey
                      : open
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 7),
                Text(
                  past
                      ? 'انقضى'
                      : open
                          ? 'الحجز مفتوح'
                          : 'الحجز مغلق',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: past
                        ? Colors.grey
                        : open
                            ? Colors.green
                            : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
      String label, dynamic price, int booked, int total, bool past) {
    final full = booked >= total;

    return Row(
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
            color: past ? Colors.grey : const Color(0xFF1F2937),
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
            color: full
                ? Colors.orange.withValues(alpha: 0.12)
                : const Color(0xFFF1F2F5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$booked/$total',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: full ? Colors.orange.shade800 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا توجد أسابيع',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
