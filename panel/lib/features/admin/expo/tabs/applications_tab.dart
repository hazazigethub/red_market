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

  Future<void> _approve(Map<String, dynamic> a, List halls) async {
    String? hallId = halls.isNotEmpty ? '${halls.first['id']}' : null;
    String tier = '${a['requested_tier'] ?? 'standard'}';
    final slot = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('قبول ${a['store']?['name'] ?? ''}',
                style: const TextStyle(
                    fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: hallId,
                  decoration: expoInput('القاعة'),
                  items: halls
                      .map((h) => DropdownMenuItem(
                          value: '${h['id']}',
                          child: Text('${h['name']}',
                              style: const TextStyle(fontFamily: kExpoFont))))
                      .toList(),
                  onChanged: (v) => setD(() => hallId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slot,
                  textDirection: TextDirection.ltr,
                  decoration: expoInput('موقع الجناح في الخريطة', hint: 'A-01'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  decoration: expoInput('نوع الجناح'),
                  items: kBoothTier.entries
                      .map((t) => DropdownMenuItem(
                          value: t.key,
                          child: Text(t.value,
                              style: const TextStyle(fontFamily: kExpoFont))))
                      .toList(),
                  onChanged: (v) => setD(() => tier = v ?? 'standard'),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء',
                      style: TextStyle(fontFamily: kExpoFont))),
              expoButton('قبول', () => Navigator.pop(ctx, true), primary: true),
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
        ok: 'تم القبول وإنشاء الجناح');
    if (ok && mounted) setState(() {});
  }

  Future<void> _reject(Map<String, dynamic> a) async {
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض الطلب',
              style: TextStyle(fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
          content: TextField(
              controller: note,
              maxLines: 3,
              decoration: expoInput('سبب الرفض (يصل للتاجر)')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('إلغاء', style: TextStyle(fontFamily: kExpoFont))),
            expoButton('رفض', () => Navigator.pop(ctx, true), primary: true),
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
        ok: 'تم رفض الطلب');
    if (ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
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

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              ChoiceChip(
                  label: const Text('المعلقة', style: TextStyle(fontFamily: kExpoFont)),
                  selected: !_all,
                  onSelected: (_) => setState(() => _all = false)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: const Text('الكل', style: TextStyle(fontFamily: kExpoFont)),
                  selected: _all,
                  onSelected: (_) => setState(() => _all = true)),
            ]),
            const SizedBox(height: 12),
            if (apps.isEmpty) expoEmpty('لا توجد طلبات'),
            ...apps.map((a) {
              final sub = subOf(a['store_id']);
              final subStatus = '${sub?['status'] ?? 'none'}';
              final pending = a['status'] == 'pending';
              return ExpoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${a['store']?['name'] ?? 'متجر'}',
                            style: const TextStyle(
                                fontFamily: kExpoFont,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        expoChip('طلب: ${kBoothTier['${a['requested_tier']}'] ?? ''}',
                            Colors.blueGrey),
                        expoChip(kApplicationStatus['${a['status']}'] ?? '${a['status']}',
                            pending ? Colors.orange : Colors.grey),
                        expoChip(
                            '${kSubscriptionStatus[subStatus]}'
                            '${sub?['expires_at'] != null ? ' · حتى ${expoFmtDate(sub!['expires_at'])}' : ''}',
                            subStatus == 'ok' ? Colors.green : Colors.red),
                        expoSub(expoFmtDateTime(a['created_at'])),
                      ],
                    ),
                    if ((a['message'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${a['message']}',
                          style: const TextStyle(fontFamily: kExpoFont, fontSize: 12.5)),
                    ],
                    if (!pending && a['review_note'] != null) ...[
                      const SizedBox(height: 6),
                      expoSub('ملاحظة: ${a['review_note']}'),
                    ],
                    if (pending) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        expoButton('قبول', () => _approve(a, halls), primary: true),
                        expoButton('رفض', () => _reject(a)),
                      ]),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
