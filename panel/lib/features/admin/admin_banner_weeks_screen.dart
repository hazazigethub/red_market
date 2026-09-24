import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminBannerWeeksScreen extends StatefulWidget {
  const AdminBannerWeeksScreen({super.key});

  @override
  State<AdminBannerWeeksScreen> createState() => _AdminBannerWeeksScreenState();
}

class _AdminBannerWeeksScreenState extends State<AdminBannerWeeksScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _weeks = [];
  final Map<String, int> _bookedWide = {};
  final Map<String, int> _bookedSmall = {};

  bool _loading = true;
  bool _generating = false;
  int _year = DateTime.now().year;
  int? _busyMonth;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
      ),
    );
  }

  DateTime? _date(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// يوم بداية الأسبوع حسب الأسابيع الموجودة (الافتراضي الأحد)
  int get _weekStartDay {
    for (final w in _weeks) {
      final d = _date(w['week_start']);
      if (d != null) return d.weekday;
    }
    return DateTime.sunday;
  }

  /// أسابيع السنة المعروضة: 52 خانة (أو 53 إن وُجد)، المولَّد منها مربوط بسجلّه
  List<_WeekSlot> _yearSlots() {
    final inYear = _weeks.where((w) => (w['year'] as num?)?.toInt() == _year);
    final byNumber = <int, Map<String, dynamic>>{
      for (final w in inYear)
        if (w['week_number'] != null) (w['week_number'] as num).toInt(): w,
    };

    // بداية أسبوع 1: من سجل موجود، وإلا أول يوم بداية أسبوع في السنة
    // (نفس منطق generate_banner_weeks: الأسبوع ينتمي لسنة يوم بدايته)
    DateTime? week1;
    for (final e in byNumber.entries) {
      final d = _date(e.value['week_start']);
      if (d != null) {
        week1 = d.subtract(Duration(days: 7 * (e.key - 1)));
        break;
      }
    }
    week1 ??= _firstWeekStart(_year);

    // عدد أسابيع السنة = عدد أيام بداية الأسبوع فيها (52 أو 53)
    int count = 0;
    while (week1.add(Duration(days: 7 * count)).year == _year) {
      count++;
    }

    return List.generate(count, (i) {
      final n = i + 1;
      final rec = byNumber[n];
      final start =
          _date(rec?['week_start']) ?? week1!.add(Duration(days: 7 * i));
      return _WeekSlot(n, start, rec);
    });
  }

  /// أول يوم بداية أسبوع في السنة (الأحد)
  DateTime _firstWeekStart(int year) {
    final jan1 = DateTime(year, 1, 1);
    final forward = (_weekStartDay - jan1.weekday + 7) % 7;
    return jan1.add(Duration(days: forward));
  }

  /// الشهر الذي ينتمي له الأسبوع = شهر يوم بدايته
  int _slotMonth(_WeekSlot w) => w.start.month;

  /// كم أسبوع ناقص حتى آخر أسبوع في الشهر
  /// (الدالة تكمل من آخر week_start + 7، أو من أول أحد في السنة الحالية)
  int _missingFor(List<_WeekSlot> monthSlots) {
    if (monthSlots.every((w) => w.rec != null)) return 0;
    final target = monthSlots.last.start;
    DateTime? lastStart;
    for (final w in _weeks) {
      final d = _date(w['week_start']);
      if (d != null && (lastStart == null || d.isAfter(lastStart))) {
        lastStart = d;
      }
    }
    final from =
        lastStart ??
        _firstWeekStart(DateTime.now().year).subtract(const Duration(days: 7));
    if (!target.isAfter(from)) return 0;
    return (target.difference(from).inDays / 7).ceil();
  }

  /// تفعيل الشهر: يولّد الأسابيع الناقصة حتى آخر أسبوع فيه
  Future<void> _activateMonth(int month, int count) async {
    if (_busyMonth != null || count <= 0) return;
    if (count > 60) {
      _snack('فعّل الأشهر بالترتيب — هذا الشهر بعيد جداً', Colors.orange);
      return;
    }
    setState(() => _busyMonth = month);
    try {
      await supabase.rpc('generate_banner_weeks', params: {'p_count': count});
      await _load();
      _snack('تم تفعيل الشهر', Colors.green);
    } catch (e) {
      debugPrint('Generate error: $e');
      _snack('تعذر تفعيل الشهر', Colors.red);
    } finally {
      if (mounted) setState(() => _busyMonth = null);
    }
  }

  /// فتح أو إغلاق الحجز لأسابيع الشهر القادمة
  Future<void> _setMonthOpen(
    int month,
    List<_WeekSlot> slots,
    bool open,
  ) async {
    final ids = slots
        .where((w) => w.rec != null && !_isPast(w.rec!))
        .map((w) => w.rec!['id'])
        .toList();
    if (ids.isEmpty || _busyMonth != null) return;
    setState(() => _busyMonth = month);
    try {
      await supabase
          .from('banner_weeks')
          .update({'is_open': open})
          .inFilter('id', ids);
      await _load();
      _snack(open ? 'فُتح حجز الشهر' : 'أُغلق حجز الشهر', Colors.green);
    } catch (e) {
      debugPrint('Toggle month error: $e');
      _snack('تعذر التعديل', Colors.red);
    } finally {
      if (mounted) setState(() => _busyMonth = null);
    }
  }

  /// نافذة تعديل الأسبوع
  void _editDialog(Map<String, dynamic> w) {
    final occasion = TextEditingController(
      text: (w['occasion_name'] ?? '').toString(),
    );
    final priceWide = TextEditingController(
      text: '${(w['price_wide'] as num?)?.toInt() ?? 0}',
    );
    final priceSmall = TextEditingController(
      text: '${(w['price_small'] as num?)?.toInt() ?? 0}',
    );
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
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.edit_calendar_rounded,
                    color: brandRed,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'الأسبوع ${w['week_number']} · ${w['year']} — '
                    '${_fmt(w['week_start'])} إلى ${_fmt(w['week_end'])}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
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
                    title: const Text(
                      'الحجز مفتوح',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      isOpen
                          ? 'يستطيع التجار الحجز في هذا الأسبوع'
                          : 'الحجز مغلق — لا يظهر للتجار',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                      ),
                    ),
                    onChanged: (v) => setModal(() => isOpen = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        setModal(() => saving = true);
                        try {
                          await supabase
                              .from('banner_weeks')
                              .update({
                                'occasion_name': occasion.text.trim().isEmpty
                                    ? null
                                    : occasion.text.trim(),
                                'price_wide':
                                    int.tryParse(priceWide.text.trim()) ?? 0,
                                'price_small':
                                    int.tryParse(priceSmall.text.trim()) ?? 0,
                                'is_open': isOpen,
                              })
                              .eq('id', w['id']);

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          _snack('حُفظ الأسبوع', Colors.green);
                        } catch (e) {
                          debugPrint('Save error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر الحفظ', Colors.red);
                        }
                      },
                child: Text(
                  saving ? 'جاري الحفظ...' : 'حفظ',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: Colors.grey.shade400,
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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

  static const _monthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  Widget build(BuildContext context) {
    final slots = _loading ? <_WeekSlot>[] : _yearSlots();
    final generated = slots.where((w) => w.rec != null).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'الأسابيع الإعلانية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'فعّل الشهر من بطاقته، واضغط أي أسبوع لتعديل أسعاره أو مناسبته',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 18),

              // ===== شريط السنة =====
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEDEFF3)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _year--),
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        color: Colors.grey.shade700,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$_year',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$generated من ${slots.length} أسبوع مفعّل',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _year++),
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        color: Colors.grey.shade700,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: brandRed),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(12, (i) {
                    final month = i + 1;
                    final monthSlots = slots
                        .where((w) => _slotMonth(w) == month)
                        .toList();
                    return _monthCard(month, monthSlots);
                  }),
                ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _legend('مفتوح', Colors.white, const Color(0xFFD5D8DE)),
                  _legend(
                    'مغلق',
                    const Color(0xFFF1F2F5),
                    const Color(0xFFE5E7EB),
                  ),
                  _legend(
                    'مناسبة',
                    Colors.white,
                    brandRed.withValues(alpha: 0.5),
                  ),
                  _legend(
                    'غير مفعّل',
                    const Color(0xFFFAFAFA),
                    const Color(0xFFF1F2F5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthCard(int month, List<_WeekSlot> monthSlots) {
    final missing = monthSlots.isEmpty ? 0 : _missingFor(monthSlots);
    final upcoming = monthSlots
        .where((w) => w.rec != null && !_isPast(w.rec!))
        .toList();
    final allOpen =
        upcoming.isNotEmpty && upcoming.every((w) => w.rec!['is_open'] == true);
    final busy = _busyMonth == month;

    Widget? action;
    if (missing > 0) {
      action = _monthButton(
        label: busy ? 'جاري...' : 'تفعيل',
        filled: true,
        onTap: busy ? null : () => _activateMonth(month, missing),
      );
    } else if (upcoming.isNotEmpty) {
      action = _monthButton(
        label: busy ? 'جاري...' : (allOpen ? 'إغلاق' : 'فتح'),
        filled: !allOpen,
        onTap: busy ? null : () => _setMonthOpen(month, monthSlots, !allOpen),
      );
    }

    return Container(
      width: _monthCardWidth,
      padding: const EdgeInsets.all(12),
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
              Text(
                _monthNames[month - 1],
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              if (upcoming.isNotEmpty)
                Icon(
                  allOpen
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 13,
                  color: allOpen ? Colors.green : Colors.orange,
                ),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: monthSlots.map(_weekTile).toList(),
          ),
        ],
      ),
    );
  }

  Widget _weekTile(_WeekSlot slot) {
    final week = slot.rec;
    final exists = week != null;
    final past = exists && _isPast(week!);
    final open = exists && week!['is_open'] == true;
    final occasion = exists ? (week!['occasion_name'] ?? '').toString() : '';

    int wide = 0, small = 0, wideTotal = 20, smallTotal = 20;
    if (exists) {
      final id = week!['id'].toString();
      wide = _bookedWide[id] ?? 0;
      small = _bookedSmall[id] ?? 0;
      wideTotal = (week!['wide_slots_total'] as num?)?.toInt() ?? 20;
      smallTotal = (week!['small_slots_total'] as num?)?.toInt() ?? 20;
    }

    final end = slot.start.add(const Duration(days: 6));

    final Color fill = !exists
        ? const Color(0xFFFAFAFA)
        : open
        ? Colors.white
        : const Color(0xFFF1F2F5);
    final Color border = !exists
        ? const Color(0xFFF1F2F5)
        : occasion.isNotEmpty
        ? brandRed.withValues(alpha: 0.5)
        : open
        ? const Color(0xFFD5D8DE)
        : const Color(0xFFE5E7EB);
    final Color stateColor = past
        ? Colors.grey
        : open
        ? Colors.green
        : Colors.orange;

    final tile = Opacity(
      opacity: past ? 0.5 : 1,
      child: Container(
        width: _tileSize,
        height: _tileSize,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${slot.number}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: !exists
                        ? Colors.grey.shade400
                        : past
                        ? Colors.grey
                        : brandRed,
                  ),
                ),
                const Spacer(),
                if (exists)
                  Icon(
                    past
                        ? Icons.history_rounded
                        : open
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    size: 12,
                    color: stateColor,
                  ),
              ],
            ),
            Text(
              '${slot.start.day}/${slot.start.month} – ${end.day}/${end.month}',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
            const Spacer(),
            if (occasion.isNotEmpty)
              Text(
                occasion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: brandRed,
                ),
              ),
            if (exists) ...[
              Text(
                'عريض $wide/$wideTotal',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'صغير $small/$smallTotal',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else
              Text(
                'غير مفعّل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
      ),
    );

    if (!exists || past) return tile;

    return InkWell(
      onTap: () => _editDialog(week!),
      borderRadius: BorderRadius.circular(10),
      child: tile,
    );
  }

  static const double _tileSize = 86;
  static const double _monthCardWidth = 5 * 86 + 4 * 6 + 24 + 2;

  Widget _monthButton({
    required String label,
    required bool filled,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: filled ? brandRed : Colors.white,
          foregroundColor: filled ? Colors.white : brandRed,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: brandRed.withValues(alpha: 0.4)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _WeekSlot {
  final int number;
  final DateTime start;
  final Map<String, dynamic>? rec;
  const _WeekSlot(this.number, this.start, this.rec);
}
