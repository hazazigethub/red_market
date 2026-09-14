import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRefundsScreen extends StatefulWidget {
  const AdminRefundsScreen({super.key});

  @override
  State<AdminRefundsScreen> createState() => _AdminRefundsScreenState();
}

class _AdminRefundsScreenState extends State<AdminRefundsScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _storeNames = {};
  bool _loading = true;
  String _filter = 'pending';

  static const _filters = [
    (key: 'pending', label: 'قيد المعالجة'),
    (key: 'completed', label: 'مكتملة'),
    (key: 'rejected', label: 'مرفوضة'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('refund_requests')
          .select()
          .eq('status', _filter)
          .order('requested_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(data);

      // أسماء المتاجر
      final ids = rows
          .map((r) => r['merchant_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final merchants = await supabase
            .from('merchants')
            .select('id, store_name')
            .inFilter('id', ids);

        for (final m in List<Map<String, dynamic>>.from(merchants)) {
          names[m['id'].toString()] =
              (m['store_name'] ?? 'متجر').toString();
        }
      }

      if (mounted) {
        setState(() {
          _rows = rows;
          _storeNames = names;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Refunds load error: $e');
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

  Future<void> _updateStatus(
      Map<String, dynamic> row, String status, String? note) async {
    try {
      await supabase.from('refund_requests').update({
        'status': status,
        'processed_at': DateTime.now().toIso8601String(),
        'admin_note': note,
      }).eq('id', row['id']);

      await _load();
      _snack(
        status == 'completed' ? 'تم تأكيد الاسترداد' : 'تم رفض الطلب',
        status == 'completed' ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _snack('تعذر التحديث', Colors.red);
    }
  }

  void _confirmDialog(Map<String, dynamic> row, String status) {
    final noteCtrl = TextEditingController();
    final isComplete = status == 'completed';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isComplete ? 'تأكيد الاسترداد' : 'رفض الطلب',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? 'أكّد أنك أعدت ${(row['amount'] as num?)?.toStringAsFixed(0) ?? '0'} ر.س إلى وسيلة الدفع الأصلية.'
                      : 'سيُرفض الطلب ولن يُعاد المبلغ.',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ملاحظة (اختياري)',
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
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isComplete ? Colors.green : Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(row, status,
                    noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
              },
              child: Text(isComplete ? 'تأكيد' : 'رفض',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return "${d.year}/${d.month}/${d.day}";
  }

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
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('طلبات الاسترداد',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text('${_rows.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    children: _filters.map((f) {
                      final on = _filter == f.key;
                      return GestureDetector(
                        onTap: () {
                          if (_filter == f.key) return;
                          setState(() => _filter = f.key);
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: on ? brandRed : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: on
                                    ? brandRed
                                    : const Color(0xFFEDEFF3)),
                          ),
                          child: Text(
                            f.label,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight:
                                  on ? FontWeight.bold : FontWeight.normal,
                              color: on ? Colors.white : Colors.grey.shade700,
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
                          child:
                              CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_rows.isEmpty)
                    _empty()
                  else
                    ..._rows.map(_card),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final store = _storeNames[r['merchant_id']?.toString()] ?? 'متجر';
    final pending = r['status'] == 'pending';
    final method = (r['payment_method'] ?? '').toString();
    final paymentId = (r['payment_id'] ?? '').toString();
    final note = (r['admin_note'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.replay_circle_filled_rounded,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold)),
                    Text((r['plan_name'] ?? '').toString(),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Text('${amount.toStringAsFixed(0)} ر.س',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: brandRed)),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 14),

          _line('تاريخ الطلب', _fmt(r['requested_at'])),
          const SizedBox(height: 8),
          _line('وسيلة الاسترداد',
              method.isEmpty ? '— لم تُسجَّل' : method),
          const SizedBox(height: 8),
          _line('معرّف العملية',
              paymentId.isEmpty ? '— بانتظار ربط البوابة' : paymentId),

          if (r['processed_at'] != null) ...[
            const SizedBox(height: 8),
            _line('تاريخ المعالجة', _fmt(r['processed_at'])),
          ],

          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(note,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 12, height: 1.7)),
            ),
          ],

          if (pending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDialog(r, 'completed'),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('تم الاسترداد',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _confirmDialog(r, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('رفض',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.replay_circle_filled_outlined,
              size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا توجد طلبات',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
