import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// شريط أخبار متحرّك — رسائله تُدار من «شريط الأخبار» في لوحة الأدمن
class NewsTicker extends StatefulWidget {
  /// 'merchant' أو 'customer' — ورسائل 'all' تظهر للجميع
  final String audience;

  /// يظهر في رأس الشريط — يميّز الشريطين عند الأدمن
  final String? label;

  const NewsTicker({super.key, required this.audience, this.label});

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker>
    with SingleTickerProviderStateMixin {
  static const Color _brand = Color(0xFFD32027);
  static const double _speed = 90; // بكسل في الثانية

  final _contentKey = GlobalKey();

  List<String> _messages = const [];
  Ticker? _ticker;
  double _offset = 0;
  double _contentWidth = 0;

  /// نسخ تكفي لملء عرض الشريط — وإلا ظهرت الرسائل في نطاق ضيّق
  int _copies = 2;
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      final rows = await Supabase.instance.client
          .from('ticker_messages')
          .select('text, sort_order, expires_at, audience')
          .eq('is_active', true)
          .inFilter('audience', [widget.audience, 'all'])
          .order('sort_order');

      final list = <String>[];
      for (final r in (rows as List)) {
        final exp = r['expires_at']?.toString();
        if (exp != null && exp.compareTo(today) < 0) continue;

        final t = (r['text'] ?? '').toString().trim();
        if (t.isNotEmpty) list.add(t);
      }

      if (!mounted || list.isEmpty) return;

      setState(() => _messages = list);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
    } catch (_) {
      // الشريط تكميلي — لا نُفشل الصفحة
    }
  }

  void _startScroll() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;

    _contentWidth = box.size.width;
    if (_contentWidth <= 0) return;

    // نسخة تُعرض ونسخ تملأ ما تبقّى من العرض
    final need = (_viewport / _contentWidth).ceil() + 1;
    if (need > _copies) {
      setState(() => _copies = need);
    }

    if (_ticker != null) return;

    Duration? last;
    _ticker = createTicker((elapsed) {
      final dt = last == null
          ? 0.0
          : (elapsed - last!).inMicroseconds / 1000000.0;
      last = elapsed;

      if (!mounted) return;
      setState(() {
        _offset += _speed * dt;
        if (_offset >= _contentWidth) _offset -= _contentWidth;
      });
    })
      ..start();
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.06),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                _viewport = c.maxWidth;

                return ClipRect(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Transform.translate(
                      offset: Offset(-_offset, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < _copies; i++)
                            _strip(key: i == 0 ? _contentKey : null),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// نسختان متتاليتان تجعلان الدوران متّصلاً بلا قفزة
  Widget _strip({Key? key}) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                widget.label!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        for (final m in _messages) ...[
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              m,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: _brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
