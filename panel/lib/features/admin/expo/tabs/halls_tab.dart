import 'package:flutter/material.dart';
import 'package:red_market_core/red_market_core.dart';

import '../expo_common.dart';

class HallsTab extends StatefulWidget {
  final String exhibitionId;
  const HallsTab({super.key, required this.exhibitionId});

  @override
  State<HallsTab> createState() => _HallsTabState();
}

class _HallsTabState extends State<HallsTab> {
  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final halls = await expoDb
        .from('exhibition_halls')
        .select('*')
        .eq('exhibition_id', widget.exhibitionId)
        .order('sort_order');
    final booths = await expoDb
        .from('booths')
        .select('id, name, slug, hall_id, map_slot, tier, status')
        .eq('exhibition_id', widget.exhibitionId)
        .order('name');
    return {'halls': halls, 'booths': booths};
  }

  // "B-03" -> (2, 3)
  (int, int)? _slot(dynamic s) {
    final m = RegExp(r'^([A-Z])-?(\d{1,2})$')
        .firstMatch('${s ?? ''}'.trim().toUpperCase());
    if (m == null) return null;
    return (m.group(1)!.codeUnitAt(0) - 64, int.parse(m.group(2)!));
  }

  Future<void> _editHall(Map<String, dynamic>? h) async {
    final name = TextEditingController(text: '${h?['name'] ?? ''}');
    final layout = Map<String, dynamic>.from((h?['map_layout'] ?? {}) as Map);
    final cols = TextEditingController(text: '${layout['cols'] ?? 6}');
    final rows = TextEditingController(text: '${layout['rows'] ?? 4}');
    final order = TextEditingController(text: '${h?['sort_order'] ?? 0}');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(h == null ? 'قاعة جديدة' : 'تعديل القاعة',
              style: const TextStyle(
                  fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: expoInput('اسم القاعة')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: cols,
                        keyboardType: TextInputType.number,
                        decoration: expoInput('أعمدة (2-12)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: rows,
                        keyboardType: TextInputType.number,
                        decoration: expoInput('صفوف (1-26)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: order,
                        keyboardType: TextInputType.number,
                        decoration: expoInput('الترتيب'))),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('إلغاء', style: TextStyle(fontFamily: kExpoFont))),
            expoButton('حفظ', () => Navigator.pop(ctx, true), primary: true),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    final values = {
      'exhibition_id': widget.exhibitionId,
      'name': name.text.trim(),
      'sort_order': int.tryParse(order.text) ?? 0,
      'map_layout': {
        'cols': (int.tryParse(cols.text) ?? 6).clamp(2, 12),
        'rows': (int.tryParse(rows.text) ?? 4).clamp(1, 26),
      },
    };
    if ('${values['name']}'.isEmpty) {
      return expoToast(context, 'اكتب اسم القاعة', error: true);
    }
    final ok = await expoRun(
        context,
        () => h == null
            ? expoDb.from('exhibition_halls').insert(values)
            : expoDb.from('exhibition_halls').update(values).eq('id', h['id']),
        ok: 'تم حفظ القاعة');
    if (ok && mounted) setState(() {});
  }

  Future<void> _deleteHall(Map<String, dynamic> h) async {
    if (!await expoConfirm(context, 'حذف القاعة',
        'الأجنحة داخلها تبقى، لكن بدون قاعة. متابعة؟')) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb.from('exhibition_halls').delete().eq('id', h['id']),
        ok: 'تم حذف القاعة');
    if (ok && mounted) setState(() {});
  }

  Future<void> _editBooth(
      Map<String, dynamic> b, List<Map<String, dynamic>> halls) async {
    String? hallId = b['hall_id'] as String?;
    String tier = '${b['tier']}';
    String status = '${b['status']}';
    final slot = TextEditingController(text: '${b['map_slot'] ?? ''}');
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('${b['name']}',
                style: const TextStyle(
                    fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String?>(
                  initialValue: hallId,
                  decoration: expoInput('القاعة'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('بدون', style: TextStyle(fontFamily: kExpoFont))),
                    ...halls.map((h) => DropdownMenuItem<String?>(
                        value: '${h['id']}',
                        child: Text('${h['name']}',
                            style: const TextStyle(fontFamily: kExpoFont)))),
                  ],
                  onChanged: (v) => setD(() => hallId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: slot,
                    textDirection: TextDirection.ltr,
                    decoration: expoInput('الموقع', hint: 'A-01')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  decoration: expoInput('النوع'),
                  items: kBoothTier.entries
                      .map((t) => DropdownMenuItem(
                          value: t.key,
                          child: Text(t.value,
                              style: const TextStyle(fontFamily: kExpoFont))))
                      .toList(),
                  onChanged: (v) => setD(() => tier = v ?? tier),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: expoInput('الظهور'),
                  items: kBoothStatus.entries
                      .map((t) => DropdownMenuItem(
                          value: t.key,
                          child: Text(t.value,
                              style: const TextStyle(fontFamily: kExpoFont))))
                      .toList(),
                  onChanged: (v) => setD(() => status = v ?? status),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: const Text('حذف الجناح',
                      style: TextStyle(fontFamily: kExpoFont, color: Colors.red))),
              const SizedBox(width: 24),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('إلغاء',
                      style: TextStyle(fontFamily: kExpoFont))),
              expoButton('حفظ', () => Navigator.pop(ctx, 'save'), primary: true),
            ],
          ),
        ),
      ),
    );
    if (go == 'delete' && mounted) {
      if (await expoConfirm(context, 'حذف الجناح نهائياً',
          'سيُحذف جناح «${b['name']}» مع منتجاته ووسائطه ومحادثاته وعملائه المحتملين. لا يمكن التراجع.')) {
        if (!mounted) return;
        final ok = await expoRun(
            context, () => expoDb.from('booths').delete().eq('id', b['id']),
            ok: 'تم حذف الجناح');
        if (ok && mounted) setState(() {});
      }
      return;
    }
    final s = slot.text.trim().toUpperCase();
    if (go != 'save' || !mounted) return;
    final ok = await expoRun(
        context,
        () => expoDb.from('booths').update({
              'hall_id': hallId,
              'map_slot': s.isEmpty ? null : s,
              'tier': tier,
              'status': status,
            }).eq('id', b['id']),
        ok: 'تم حفظ الجناح');
    if (ok && mounted) setState(() {});
  }

  Widget _map(Map<String, dynamic> hall, List<Map<String, dynamic>> booths) {
    final layout = Map<String, dynamic>.from((hall['map_layout'] ?? {}) as Map);
    final cols = ((layout['cols'] ?? 6) as num).toInt().clamp(2, 12);
    final rows = ((layout['rows'] ?? 4) as num).toInt().clamp(1, 26);
    final bySlot = <String, Map<String, dynamic>>{};
    for (final b in booths.where((b) => b['hall_id'] == hall['id'])) {
      final p = _slot(b['map_slot']);
      if (p != null) bySlot['${p.$1}-${p.$2}'] = b;
    }
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.6,
      children: [
        for (var r = 1; r <= rows; r++)
          for (var c = 1; c <= cols; c++)
            Builder(builder: (_) {
              final b = bySlot['$r-$c'];
              final code =
                  '${String.fromCharCode(64 + r)}-${c.toString().padLeft(2, '0')}';
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: b == null
                      ? Colors.transparent
                      : (b['tier'] == 'sponsor'
                          ? AppColors.brand.withValues(alpha: 0.08)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: b == null
                          ? Colors.grey.shade300
                          : (b['tier'] == 'standard'
                              ? Colors.grey.shade400
                              : AppColors.brand)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(code,
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                    if (b != null)
                      Text('${b['name']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: kExpoFont,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final halls = snap.data!['halls']!;
        final booths = snap.data!['booths']!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              expoTitle('القاعات (${halls.length})'),
              const Spacer(),
              expoButton('قاعة جديدة', () => _editHall(null),
                  primary: true, icon: Icons.add),
            ]),
            if (halls.isEmpty) expoEmpty('لا توجد قاعات'),
            ...halls.map((h) => ExpoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Text('${h['name']}',
                            style: const TextStyle(
                                fontFamily: kExpoFont,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const Spacer(),
                        expoButton('تعديل', () => _editHall(h)),
                        if (halls.length > 1)
                          expoButton('حذف', () => _deleteHall(h)),
                      ]),
                      const SizedBox(height: 10),
                      _map(h, booths),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            expoTitle('الأجنحة (${booths.length})'),
            expoSub('الأجنحة تُنشأ عند قبول طلبات العارضين. اضغط جناحاً لتحديد قاعته وموقعه ونوعه وظهوره.'),
            const SizedBox(height: 10),
            if (booths.isEmpty) expoEmpty('لا توجد أجنحة بعد'),
            ...booths.map((b) {
              String hallName = '—';
              for (final h in halls) {
                if (h['id'] == b['hall_id']) hallName = '${h['name']}';
              }
              return ExpoCard(
                onTap: () => _editBooth(b, halls),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(
                      child: Text('${b['name']}',
                          style: const TextStyle(
                              fontFamily: kExpoFont, fontWeight: FontWeight.bold))),
                  expoSub('$hallName · ${b['map_slot'] ?? 'بدون موقع'}'),
                  const SizedBox(width: 8),
                  expoChip(kBoothTier['${b['tier']}'] ?? '', Colors.blueGrey),
                  const SizedBox(width: 6),
                  expoChip(kBoothStatus['${b['status']}'] ?? '',
                      b['status'] == 'published' ? Colors.green : Colors.grey),
                ]),
              );
            }),
          ],
        );
      },
    );
  }
}
