import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إدارة رسائل شريط الأخبار — تظهر للتجار والعملاء
class AdminTickerScreen extends StatefulWidget {
  const AdminTickerScreen({super.key});

  @override
  State<AdminTickerScreen> createState() => _AdminTickerScreenState();
}

class _AdminTickerScreenState extends State<AdminTickerScreen> {
  static const Color _brand = Color(0xFFD32027);
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _border = Color(0xFFE5E7EB);

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('ticker_messages')
          .select()
          .order('sort_order')
          .order('created_at');

      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack('تعذر الجلب: $e', Colors.red);
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

  String _audienceLabel(String? a) {
    switch (a) {
      case 'customer':
        return 'العملاء';
      case 'all':
        return 'الجميع';
      default:
        return 'التجار';
    }
  }

  // ===================== التحرير =====================

  Future<void> _edit({Map<String, dynamic>? row}) async {
    final isNew = row == null;

    final textCtrl = TextEditingController(text: row?['text']?.toString() ?? '');
    final orderCtrl =
        TextEditingController(text: (row?['sort_order'] ?? 0).toString());

    String audience = row?['audience']?.toString() ?? 'merchant';
    bool active = row?['is_active'] ?? true;
    DateTime? expiry = row?['expires_at'] == null
        ? null
        : DateTime.tryParse(row!['expires_at'].toString());

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              isNew ? 'رسالة جديدة' : 'تعديل الرسالة',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نصّ الرسالة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      decoration: _dec('اكتب ما تريد أن يراه المستخدمون...'),
                    ),
                    const SizedBox(height: 16),

                    const Text('لمن تظهر؟',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final a in const ['merchant', 'customer', 'all'])
                          ChoiceChip(
                            label: Text(_audienceLabel(a),
                                style: const TextStyle(
                                    fontFamily: 'Cairo', fontSize: 12)),
                            selected: audience == a,
                            selectedColor: _brand.withValues(alpha: 0.12),
                            onSelected: (_) => setLocal(() => audience = a),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الترتيب',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: orderCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13),
                                decoration: _dec('0'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تنتهي في (اختياري)',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: expiry ?? now,
                                    firstDate: now,
                                    lastDate:
                                        now.add(const Duration(days: 730)),
                                  );
                                  if (picked != null) {
                                    setLocal(() => expiry = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          expiry == null
                                              ? 'بلا انتهاء'
                                              : '${expiry!.year}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              color: expiry == null
                                                  ? Colors.grey.shade500
                                                  : Colors.black87),
                                        ),
                                      ),
                                      if (expiry != null)
                                        InkWell(
                                          onTap: () =>
                                              setLocal(() => expiry = null),
                                          child: Icon(Icons.close_rounded,
                                              size: 15,
                                              color: Colors.grey.shade500),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        const Text('ظاهرة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Switch(
                          value: active,
                          activeThumbColor: _brand,
                          onChanged: (v) => setLocal(() => active = v),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final text = textCtrl.text.trim();
                        if (text.isEmpty) return;

                        setLocal(() => saving = true);

                        final payload = {
                          'text': text,
                          'audience': audience,
                          'is_active': active,
                          'sort_order':
                              int.tryParse(orderCtrl.text.trim()) ?? 0,
                          'expires_at': expiry == null
                              ? null
                              : expiry!.toIso8601String().split('T').first,
                        };

                        try {
                          if (isNew) {
                            await _supabase
                                .from('ticker_messages')
                                .insert(payload);
                          } else {
                            await _supabase
                                .from('ticker_messages')
                                .update(payload)
                                .eq('id', row['id']);
                          }

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _snack('تم الحفظ', Colors.green);
                          await _load();
                        } catch (e) {
                          setLocal(() => saving = false);
                          _snack('تعذر الحفظ: $e', Colors.red);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ',
                        style: TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    try {
      await _supabase
          .from('ticker_messages')
          .update({'is_active': !(row['is_active'] ?? true)}).eq(
              'id', row['id']);
      await _load();
    } catch (e) {
      _snack('تعذر التحديث: $e', Colors.red);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('حذف الرسالة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          content: const Text('لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  elevation: 0),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await _supabase.from('ticker_messages').delete().eq('id', row['id']);
      _snack('حُذفت', Colors.orange);
      await _load();
    } catch (e) {
      _snack('تعذر الحذف: $e', Colors.red);
    }
  }

  // ===================== الواجهة =====================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 18),
                        if (_rows.isEmpty) _empty() else _list(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.campaign_outlined, color: _brand, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('شريط الأخبار',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text('رسائل متحرّكة أعلى اللوحة والموقع والتطبيق',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Color(0xFF6B7280))),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('رسالة جديدة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('لا توجد رسائل — الشريط مخفيّ',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _list() {
    return Column(
      children: [
        for (final r in _rows) ...[
          _card(r),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final active = r['is_active'] ?? true;
    final exp = r['expires_at']?.toString();

    final expired = exp != null &&
        exp.compareTo(DateTime.now().toIso8601String().split('T').first) < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (r['text'] ?? '').toString(),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.8,
                    color: active && !expired
                        ? const Color(0xFF111827)
                        : Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: active,
                activeThumbColor: _brand,
                onChanged: (_) => _toggle(r),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _tag(_audienceLabel(r['audience']?.toString()),
                  Icons.people_outline_rounded),
              _tag('ترتيب ${r['sort_order'] ?? 0}', Icons.sort_rounded),
              if (exp != null)
                _tag(expired ? 'منتهية · $exp' : 'حتى $exp',
                    Icons.event_outlined,
                    danger: expired),
              const Spacer(),
              IconButton(
                onPressed: () => _edit(row: r),
                icon: const Icon(Icons.edit_outlined, size: 17),
                color: Colors.grey.shade600,
                tooltip: 'تعديل',
              ),
              IconButton(
                onPressed: () => _delete(r),
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                color: const Color(0xFFB91C1C),
                tooltip: 'حذف',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, IconData icon, {bool danger = false}) {
    final c = danger ? const Color(0xFFB91C1C) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEF2F2) : _bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: c)),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey.shade400),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: _bg,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _brand, width: 1.4)),
    );
  }
}
