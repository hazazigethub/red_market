import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminContactsScreen extends StatefulWidget {
  const AdminContactsScreen({super.key});

  @override
  State<AdminContactsScreen> createState() => _AdminContactsScreenState();
}

class _AdminContactsScreenState extends State<AdminContactsScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  final Map<String, List<Map<String, dynamic>>> _actions = {};
  bool _loading = true;
  String _filter = 'new';

  static const _filters = [
    (key: 'new', label: 'جديدة', color: Color(0xFFD32027)),
    (key: 'in_progress', label: 'تحت الإجراء', color: Colors.orange),
    (key: 'closed', label: 'مغلقة', color: Colors.grey),
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
          .from('contact_requests')
          .select()
          .eq('status', _filter)
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(data);

      // إجراءات كل رسالة
      _actions.clear();
      final ids = rows.map((r) => r['id'].toString()).toList();
      if (ids.isNotEmpty) {
        final acts = await supabase
            .from('contact_actions')
            .select()
            .inFilter('contact_id', ids)
            .order('created_at');

        for (final a in List<Map<String, dynamic>>.from(acts)) {
          final cid = a['contact_id'].toString();
          _actions.putIfAbsent(cid, () => []).add(a);
        }
      }

      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Contacts load error: $e');
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

  /// يضيف إجراءً ويحدّث الحالة إن لزم
  Future<void> _addAction(
    Map<String, dynamic> row,
    String note, {
    String? newStatus,
  }) async {
    try {
      if (note.trim().isNotEmpty) {
        await supabase.from('contact_actions').insert({
          'contact_id': row['id'],
          'note': note.trim(),
          'admin_id': supabase.auth.currentUser?.id,
        });
      }

      if (newStatus != null) {
        await supabase.from('contact_requests').update({
          'status': newStatus,
          if (newStatus == 'closed')
            'handled_at': DateTime.now().toIso8601String(),
        }).eq('id', row['id']);
      }

      await _load();

      _snack(
        newStatus == 'closed'
            ? 'أُغلقت الرسالة'
            : newStatus == 'in_progress'
                ? 'انتقلت إلى تحت الإجراء'
                : 'أُضيف الإجراء',
        newStatus == 'closed' ? Colors.grey.shade700 : Colors.green,
      );
    } catch (e) {
      debugPrint('Action error: $e');
      _snack('تعذر تنفيذ العملية', Colors.red);
    }
  }

  /// نافذة إضافة إجراء
  void _actionDialog(
    Map<String, dynamic> row, {
    required String title,
    required String hint,
    String? newStatus,
    bool noteRequired = true,
  }) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'من: ${row['name'] ?? 'زائر'}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    newStatus == 'closed' ? Colors.grey.shade700 : brandRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (noteRequired && ctrl.text.trim().isEmpty) {
                  _snack('اكتب الإجراء أولاً', Colors.orange);
                  return;
                }
                Navigator.pop(ctx);
                _addAction(row, ctrl.text, newStatus: newStatus);
              },
              child: const Text('حفظ',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic raw, {bool withTime = true}) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    final l = d.toLocal();
    final date = "${l.year}/${l.month}/${l.day}";
    if (!withTime) return date;
    return "$date — ${l.hour}:${l.minute.toString().padLeft(2, '0')}";
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
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('رسائل التواصل',
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
                            color: on ? f.color : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    on ? f.color : const Color(0xFFEDEFF3)),
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
    final status = (r['status'] ?? 'new').toString();
    final isNew = status == 'new';
    final inProgress = status == 'in_progress';
    final isClosed = status == 'closed';

    final phone = (r['phone'] ?? '').toString();
    final email = (r['email'] ?? '').toString();
    final registered = r['user_id'] != null;
    final acts = _actions[r['id'].toString()] ?? const [];

    final borderColor = isNew
        ? brandRed.withValues(alpha: 0.3)
        : inProgress
            ? Colors.orange.withValues(alpha: 0.35)
            : const Color(0xFFEDEFF3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== الترويسة =====
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            (r['name'] ?? 'زائر').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _badge(
                          registered ? 'مسجّل' : 'زائر',
                          registered ? Colors.blue : Colors.grey,
                        ),
                        if (acts.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _badge('${acts.length} إجراء', Colors.orange),
                        ],
                      ],
                    ),
                    Text(_fmt(r['created_at']),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 14),

          // ===== بيانات التواصل =====
          if (phone.isNotEmpty) ...[
            _line(Icons.phone_android_rounded, phone),
            const SizedBox(height: 8),
          ],
          if (email.isNotEmpty) ...[
            _line(Icons.mail_outline_rounded, email),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 6),

          // ===== الرسالة =====
          Text(
            (r['subject'] ?? '').toString(),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              (r['message'] ?? '').toString(),
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12.5, height: 1.9),
            ),
          ),

          // ===== سجلّ الإجراءات =====
          if (acts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text('سجلّ الإجراءات',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 10),
            ...acts.map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(9),
                    border: Border(
                      right: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.45),
                          width: 2.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (a['note'] ?? '').toString(),
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            height: 1.8),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _fmt(a['created_at']),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )),
          ],

          // ===== الأزرار =====
          if (!isClosed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _actionDialog(
                      r,
                      title: isNew ? 'بدء الإجراء' : 'إضافة إجراء',
                      hint: 'مثال: اتصلت به وشرحت له خطوات التسجيل',
                      newStatus: isNew ? 'in_progress' : null,
                    ),
                    icon: Icon(
                        isNew
                            ? Icons.play_arrow_rounded
                            : Icons.add_comment_outlined,
                        size: 17),
                    label: Text(isNew ? 'بدء الإجراء' : 'إضافة إجراء',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _actionDialog(
                    r,
                    title: 'إغلاق الرسالة',
                    hint: 'سبب الإغلاق أو ملخّص ما تم (اختياري)',
                    newStatus: 'closed',
                    noteRequired: false,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 17),
                  label: const Text('إغلاق',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'أُغلقت في ${_fmt(r['handled_at'], withTime: false)}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }

  Widget _line(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 9),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
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
          Icon(Icons.mark_email_read_outlined,
              size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا توجد رسائل',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
