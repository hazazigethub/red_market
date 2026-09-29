import 'package:flutter/material.dart';

/// تقويمات رد ماركت الموحّدة
/// - rmPickDate: تاريخ واحد
/// - rmPickDateRange: من تاريخ إلى تاريخ
/// - rmPickDateTime: تاريخ + وقت (قائمتان منسدلتان)

const Color _brandRed = Color(0xFFD32027);
const Color _border = Color(0xFFEDEFF3);
const Color _text = Color(0xFF1F2937);

const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

String _two(int v) => v.toString().padLeft(2, '0');
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String rmFmtDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}';

/// تاريخ واحد
Future<DateTime?> rmPickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _RmCalendarDialog(
      mode: _Mode.single,
      initialStart: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

/// من تاريخ إلى تاريخ
Future<DateTimeRange?> rmPickDateRange(
  BuildContext context, {
  DateTimeRange? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final r = await showDialog<Object>(
    context: context,
    builder: (_) => _RmCalendarDialog(
      mode: _Mode.range,
      initialStart: initial?.start,
      initialEnd: initial?.end,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
  return r is DateTimeRange ? r : null;
}

/// تاريخ ووقت
Future<DateTime?> rmPickDateTime(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
  bool futureOnly = true,
}) async {
  final r = await showDialog<Object>(
    context: context,
    builder: (_) => _RmCalendarDialog(
      mode: _Mode.dateTime,
      initialStart: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      futureOnly: futureOnly,
    ),
  );
  return r is DateTime ? r : null;
}

enum _Mode { single, range, dateTime }

class _RmCalendarDialog extends StatefulWidget {
  final _Mode mode;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool futureOnly;

  const _RmCalendarDialog({
    required this.mode,
    this.initialStart,
    this.initialEnd,
    this.firstDate,
    this.lastDate,
    this.futureOnly = true,
  });

  @override
  State<_RmCalendarDialog> createState() => _RmCalendarDialogState();
}

class _RmCalendarDialogState extends State<_RmCalendarDialog> {
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;
  int _hour = 0;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initialStart != null ? _day(widget.initialStart!) : null;
    _end = widget.initialEnd != null ? _day(widget.initialEnd!) : null;

    if (widget.mode == _Mode.dateTime) {
      final base = widget.initialStart ??
          now.add(Duration(minutes: 5 - now.minute % 5));
      _start ??= _day(base);
      _hour = base.hour;
      _minute = (base.minute ~/ 5) * 5;
    }

    final anchor = _start ?? now;
    _month = DateTime(anchor.year, anchor.month);
  }

  bool _disabled(DateTime d) {
    if (widget.firstDate != null && d.isBefore(_day(widget.firstDate!))) {
      return true;
    }
    if (widget.lastDate != null && d.isAfter(_day(widget.lastDate!))) {
      return true;
    }
    return false;
  }

  void _tap(DateTime d) {
    setState(() {
      if (widget.mode == _Mode.range) {
        if (_start == null || _end != null || d.isBefore(_start!)) {
          _start = d;
          _end = null;
        } else {
          _end = d;
        }
      } else {
        _start = d;
      }
    });
  }

  DateTime? get _chosenDateTime => _start == null
      ? null
      : DateTime(_start!.year, _start!.month, _start!.day, _hour, _minute);

  bool get _valid {
    if (_start == null) return false;
    if (widget.mode == _Mode.dateTime && widget.futureOnly) {
      return _chosenDateTime!.isAfter(DateTime.now());
    }
    return true;
  }

  String get _summary {
    if (_start == null) {
      return widget.mode == _Mode.range ? 'اختر تاريخ البداية' : 'اختر التاريخ';
    }
    switch (widget.mode) {
      case _Mode.range:
        return _end == null
            ? 'اختر تاريخ النهاية'
            : '${rmFmtDate(_start!)}  ←  ${rmFmtDate(_end!)}';
      case _Mode.dateTime:
        return _valid
            ? '${rmFmtDate(_start!)}  ·  ${_two(_hour)}:${_two(_minute)}'
            : 'الموعد المختار مضى — اختر وقتاً لاحقاً';
      case _Mode.single:
        return rmFmtDate(_start!);
    }
  }

  void _confirm() {
    switch (widget.mode) {
      case _Mode.range:
        Navigator.pop(context, DateTimeRange(start: _start!, end: _end ?? _start!));
        break;
      case _Mode.dateTime:
        Navigator.pop(context, _chosenDateTime);
        break;
      case _Mode.single:
        Navigator.pop(context, _start);
        break;
    }
  }

  Widget _cell(int i, int lead) {
    if (i < lead) return const SizedBox.shrink();
    final d = DateTime(_month.year, _month.month, i - lead + 1);
    final disabled = _disabled(d);
    final isStart = _start != null && d == _start;
    final isEnd = _end != null && d == _end;
    final inRange = widget.mode == _Mode.range &&
        _start != null &&
        _end != null &&
        d.isAfter(_start!) &&
        d.isBefore(_end!);
    final sel = isStart || isEnd;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : () => _tap(d),
      child: Container(
        decoration: BoxDecoration(
          color: sel
              ? _brandRed
              : inRange
                  ? _brandRed.withValues(alpha: 0.08)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? _brandRed : _border),
        ),
        alignment: Alignment.center,
        child: Text('${d.day}',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: disabled
                    ? Colors.grey.shade300
                    : sel
                        ? Colors.white
                        : _text)),
      ),
    );
  }

  Widget _dropdown(int value, List<int> items, ValueChanged<int> onChanged) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          icon: const SizedBox.shrink(),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
          menuMaxHeight: 240,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: _text),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(_two(v))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // الأحد أول الأسبوع

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // شريط الشهر
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      color: Colors.grey.shade700,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        '${_monthNames[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      color: Colors.grey.shade700,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // أسماء الأيام
                Row(
                  children: _dayNames
                      .map((n) => Expanded(
                            child: Center(
                              child: Text(n,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8A93A6))),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    mainAxisExtent: 38,
                  ),
                  itemCount: lead + daysInMonth,
                  itemBuilder: (_, i) => _cell(i, lead),
                ),

                // الوقت
                if (widget.mode == _Mode.dateTime) ...[
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dropdown(_hour, List.generate(24, (i) => i),
                            (v) => setState(() => _hour = v)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(':',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        _dropdown(_minute, List.generate(12, (i) => i * 5),
                            (v) => setState(() => _minute = v)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Text(
                  _summary,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: (widget.mode == _Mode.dateTime &&
                              _start != null &&
                              !_valid)
                          ? _brandRed
                          : Colors.grey.shade600),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء',
                          style: TextStyle(
                              fontFamily: 'Cairo', color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _valid ? _confirm : null,
                      child: const Text('تم',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
