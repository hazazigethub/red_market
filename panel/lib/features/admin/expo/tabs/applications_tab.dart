import 'package:flutter/material.dart';

import '../expo_common.dart';

class ApplicationsTab extends StatefulWidget {
  final String exhibitionId;
  const ApplicationsTab({super.key, required this.exhibitionId});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  bool _all = false;

  Future<Map<String, dynamic>> _load() async {
    var q = expoDb
        .from('booth_applications')
        .select('*, store(name, logo_url)')
        .eq('exhibition_id', widget.exhibitionId);
    if (!_all) q = q.eq('status', 'pending');
    final apps = await q.order('created_at');
    final halls = await expoDb
        .from('exhibition_halls')
        .select('id, name')
        .eq('exhibition_id', widget.exhibitionId)
        .order('sort_order');
    final subs = await expoDb.rpc('exhibition_subscription_check',
        params: {'p_exhibition': widget.exhibitionId});
    return {'apps': apps, 'halls': halls, 'subs': subs};
  }

  DropdownMenuItem<String> _item(String value, String label) => DropdownMenuItem(
      value: value,
      child: Text(label, style: const TextStyle(fontFamily: kExpoFont, fontSize: 13)));

  Future<void> _approve(Map<String, dynamic> a, List halls) async {
    String? hallId = halls.isNotEmpty ? '${halls.first['id']}' : null;
    String tier = '${a['requested_tier'] ?? 'standard'}';
    final slot = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: expoDialogTitle(
                'قبول ${a['store']?['name'] ?? ''}', Icons.how_to_reg_outlined),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: hallId,
                  decoration: expoInput('القاعة', icon: Icons.grid_view_rounded),
                  items: halls.map((h) => _item('${h['id']}', '${h['name']}')).toList(),
                  onChanged: (v) => setD(() => hallId = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: slot,
                  textDirection: TextDirection.ltr,
                  style: kExpoFieldText,
                  decoration: expoInput('موقع الجناح في الخريطة',
                      hint: 'A-01', icon: Icons.place_outlined),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  decoration:
                      expoInput('نوع الجناح', icon: Icons.workspace_premium_outlined),
                  items: kBoothTier.entries.map((t) => _item(t.key, t.value)).toList(),
                  onChanged: (v) => setD(() => tier = v ?? 'standard'),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء',
                      style: TextStyle(fontFamily: kExpoFont, color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('قبول وإنشاء الجناح',
                    style: TextStyle(
                        fontFamily: kExpoFont,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
    final s = slot.text.trim().toUpperCase();
    slot.dispose();
    if (go != true || !mounted) return;
    final ok = await expoRun(
        context,
        () => expoDb.rpc('review_application', params: {
              'p_application': a['id'],
              'p_approve': true,
              'p_hall': hallId,
              'p_slot': s.isEmpty ? null : s,
              'p_tier': tier,
            }),
        ok: 'قُبل الطلب وأُنشئ الجناح');
    if (ok && mounted) setState(() {});
  }

  Future<void> _reject(Map<String, dynamic> a) async {
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: expoDialogTitle('رفض الطلب', Icons.block_rounded),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
            child: TextField(
                controller: note,
                maxLines: 3,
                style: kExpoFieldText,
                decoration: expoInput('سبب الرفض — يصل للتاجر',
                    icon: Icons.notes_rounded)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع',
                    style: TextStyle(fontFamily: kExpoFont, color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رفض الطلب',
                  style: TextStyle(
                      fontFamily: kExpoFont,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    final n = note.text.trim();
    note.dispose();
    if (go != true || !mounted) return;
    final ok = await expoRun(
        context,
        () => expoDb.rpc('review_application', params: {
              'p_application': a['id'],
              'p_approve': false,
              'p_note': n.isEmpty ? null : n,
            }),
        ok: 'رُفض الطلب');
    if (ok && mounted) setState(() {});
  }

  Widget _filter(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? kInk : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: on ? kInk : kLine),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 12,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal,
                  color: on ? Colors.white : Colors.grey.shade700)),
        ),
      );

  Widget _card(Map<String, dynamic> a, List halls, Map<String, dynamic>? sub) {
    final subStatus = '${sub?['status'] ?? 'none'}';
    final pending = a['status'] == 'pending';
    final logo = a['store']?['logo_url'] as String?;
    return ExpoCard(
      borderColor: pending && subStatus != 'ok' ? Colors.red.withValues(alpha: 0.25) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: kBrand.withValues(alpha: 0.08),
              backgroundImage: logo != null ? NetworkImage(logo) : null,
              child: logo == null
                  ? const Icon(Icons.storefront_outlined, color: kBrand, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${a['store']?['name'] ?? 'متجر'}',
                      style: const TextStyle(
                          fontFamily: kExpoFont,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  expoSub('قُدّم ${expoFmtDateTime(a['created_at'])}'),
                ],
              ),
            ),
            expoChip(kApplicationStatus['${a['status']}'] ?? '${a['status']}',
                pending ? Colors.orange : Colors.grey),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 18, runSpacing: 6, children: [
            expoStat(Icons.workspace_premium_outlined,
                'طلب جناح ${kBoothTier['${a['requested_tier']}'] ?? ''}'),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(subStatus == 'ok' ? Icons.verified_outlined : Icons.error_outline_rounded,
                  size: 14, color: subStatus == 'ok' ? Colors.green : Colors.red),
              const SizedBox(width: 6),
              Text(
                  '${kSubscriptionStatus[subStatus]}'
                  '${sub?['expires_at'] != null ? ' · حتى ${expoFmtDate(sub!['expires_at'])}' : ''}',
                  style: TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 11.5,
                      color: subStatus == 'ok' ? Colors.green.shade700 : Colors.red)),
            ]),
          ]),
          if ((a['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: kBg, borderRadius: BorderRadius.circular(11)),
              child: Text('${a['message']}',
                  style: TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 12,
                      height: 1.8,
                      color: Colors.grey.shade700)),
            ),
          ],
          if (!pending && a['review_note'] != null) ...[
            const SizedBox(height: 8),
            expoStat(Icons.notes_rounded, 'ملاحظة: ${a['review_note']}'),
          ],
          if (pending) ...[
            const SizedBox(height: 14),
            kExpoDivider,
            const SizedBox(height: 12),
            Row(children: [
              const Spacer(),
              expoButton('رفض', () => _reject(a), icon: Icons.close_rounded),
              expoButton('قبول', () => _approve(a, halls),
                  primary: true, icon: Icons.check_rounded),
            ]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        final filters = Row(children: [
          _filter('بانتظار المراجعة', !_all, () => setState(() => _all = false)),
          const SizedBox(width: 8),
          _filter('كل الطلبات', _all, () => setState(() => _all = true)),
        ]);
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(children: [filters, expoLoader()]);
        }
        if (snap.hasError) return expoFailed(snap.error);
        final apps = List<Map<String, dynamic>>.from(snap.data!['apps'] as List);
        final halls = snap.data!['halls'] as List;
        final subs = List<Map<String, dynamic>>.from(snap.data!['subs'] as List);
        Map<String, dynamic>? subOf(dynamic storeId) {
          for (final s in subs) {
            if (s['store_id'] == storeId) return s;
          }
          return null;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            filters,
            const SizedBox(height: 14),
            if (apps.isEmpty)
              expoEmpty(_all ? 'لا طلبات بعد' : 'لا طلبات بانتظار المراجعة',
                  icon: Icons.how_to_reg_outlined)
            else
              expoGrid(apps.map((a) => _card(a, halls, subOf(a['store_id']))).toList(),
                  maxCols: 2),
          ],
        );
      },
    );
  }
}
