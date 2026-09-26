import 'package:flutter/material.dart';

import '../expo_common.dart';

class HallsTab extends StatefulWidget {
  final String exhibitionId;
  const HallsTab({super.key, required this.exhibitionId});

  @override
  State<HallsTab> createState() => _HallsTabState();
}

class _HallsTabState extends State<HallsTab> {
  int? _maxBooths; // «عدد الأجنحة المتاحة» للمعرض — يحدد مقاس الخرائط

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final ex = await expoDb
        .from('exhibitions')
        .select('max_booths')
        .eq('id', widget.exhibitionId)
        .single();
    _maxBooths = (ex['max_booths'] as num?)?.toInt();
    final halls = await expoDb
        .from('exhibition_halls')
        .select('*')
        .eq('exhibition_id', widget.exhibitionId)
        .order('sort_order');
    final booths = await expoDb
        .from('booths')
        .select('id, name, slug, hall_id, map_slot, tier, status, logo_path')
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

  DropdownMenuItem<T> _item<T>(T value, String label) => DropdownMenuItem<T>(
      value: value,
      child: Text(label, style: const TextStyle(fontFamily: kExpoFont, fontSize: 13)));

  Widget _dialogActions(BuildContext ctx, {String saveLabel = 'حفظ'}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: kExpoFont, color: Colors.grey))),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(saveLabel,
                style: const TextStyle(
                    fontFamily: kExpoFont,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      );

  // ===================== القاعات =====================

  Future<void> _editHall(Map<String, dynamic>? h) async {
    final name = TextEditingController(text: '${h?['name'] ?? ''}');
    final layout = Map<String, dynamic>.from((h?['map_layout'] ?? {}) as Map);
    final cols = TextEditingController(text: '${layout['cols'] ?? 6}');
    final rows = TextEditingController(text: '${layout['rows'] ?? 4}');
    final order = TextEditingController(text: '${h?['sort_order'] ?? 0}');
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: expoDialogTitle(
              h == null ? 'قاعة جديدة' : 'تعديل القاعة', Icons.grid_view_rounded),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  style: kExpoFieldText,
                  decoration: expoInput('اسم القاعة', icon: Icons.title_rounded)),
              const SizedBox(height: 14),
              expoFormSection('مقاس الخريطة', Icons.grid_on_rounded,
                  note: _maxBooths == null
                      ? 'الصفوف أحرف A، B… والأعمدة أرقام'
                      : 'الصفوف تُحسب تلقائياً من عدد الأجنحة'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: cols,
                        keyboardType: TextInputType.number,
                        style: kExpoFieldText,
                        decoration: expoInput('أعمدة (2-12)'))),
                if (_maxBooths == null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: rows,
                          keyboardType: TextInputType.number,
                          style: kExpoFieldText,
                          decoration: expoInput('صفوف (1-26)'))),
                ],
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: order,
                        keyboardType: TextInputType.number,
                        style: kExpoFieldText,
                        decoration: expoInput('الترتيب'))),
              ]),
            ]),
          ),
          actions: [_dialogActions(ctx)],
        ),
      ),
    );
    if (go != 'save' || !mounted) return;
    if (name.text.trim().isEmpty) {
      return expoToast(context, 'اكتب اسم القاعة', warn: true);
    }
    final values = {
      'exhibition_id': widget.exhibitionId,
      'name': name.text.trim(),
      'sort_order': int.tryParse(order.text) ?? 0,
      'map_layout': {
        'cols': (int.tryParse(cols.text) ?? 6).clamp(2, 12),
        'rows': (int.tryParse(rows.text) ?? 4).clamp(1, 26),
      },
    };
    final ok = await expoRun(
        context,
        () => h == null
            ? expoDb.from('exhibition_halls').insert(values)
            : expoDb.from('exhibition_halls').update(values).eq('id', h['id']),
        ok: 'حُفظت القاعة');
    if (ok && mounted) setState(() {});
  }

  Future<void> _deleteHall(Map<String, dynamic> h) async {
    if (!await expoConfirm(context, 'حذف القاعة',
        'ستُحذف «${h['name']}». الأجنحة داخلها تبقى بدون قاعة حتى تنقلها.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb.from('exhibition_halls').delete().eq('id', h['id']),
        ok: 'حُذفت القاعة');
    if (ok && mounted) setState(() {});
  }

  // ===================== الأجنحة =====================

  Future<void> _editBooth(
      Map<String, dynamic> b, List<Map<String, dynamic>> halls) async {
    String? hallId = b['hall_id'] as String?;
    String tier = '${b['tier']}';
    String status = '${b['status']}';
    final slot = TextEditingController(text: '${b['map_slot'] ?? ''}');
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: expoDialogTitle('${b['name']}', Icons.storefront_outlined),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String?>(
                  initialValue: hallId,
                  decoration: expoInput('القاعة', icon: Icons.grid_view_rounded),
                  items: [
                    _item<String?>(null, 'بدون قاعة'),
                    ...halls.map((h) => _item<String?>('${h['id']}', '${h['name']}')),
                  ],
                  onChanged: (v) => setD(() => hallId = v),
                ),
                const SizedBox(height: 14),
                TextField(
                    controller: slot,
                    textDirection: TextDirection.ltr,
                    style: kExpoFieldText,
                    decoration: expoInput('الموقع في الخريطة',
                        hint: 'A-01', icon: Icons.place_outlined)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: tier,
                      decoration: expoInput('النوع'),
                      items: kBoothTier.entries.map((t) => _item(t.key, t.value)).toList(),
                      onChanged: (v) => setD(() => tier = v ?? tier),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: expoInput('الظهور'),
                      items: kBoothStatus.entries.map((t) => _item(t.key, t.value)).toList(),
                      onChanged: (v) => setD(() => status = v ?? status),
                    ),
                  ),
                ]),
              ]),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                label: const Text('حذف الجناح',
                    style: TextStyle(fontFamily: kExpoFont, color: Colors.red)),
              ),
              _dialogActions(ctx),
            ],
          ),
        ),
      ),
    );
    final s = slot.text.trim().toUpperCase();
    slot.dispose();
    if (!mounted) return;
    if (go == 'delete') {
      if (!await expoConfirm(context, 'حذف الجناح نهائياً',
          'سيُحذف جناح «${b['name']}» مع منتجاته ووسائطه ومحادثاته وعملائه المحتملين.',
          danger: true)) {
        return;
      }
      if (!mounted) return;
      final ok = await expoRun(
          context, () => expoDb.from('booths').delete().eq('id', b['id']),
          ok: 'حُذف الجناح');
      if (ok && mounted) setState(() {});
      return;
    }
    if (go != 'save') return;
    final ok = await expoRun(
        context,
        () => expoDb.from('booths').update({
              'hall_id': hallId,
              'map_slot': s.isEmpty ? null : s,
              'tier': tier,
              'status': status,
            }).eq('id', b['id']),
        ok: 'حُفظ الجناح');
    if (ok && mounted) setState(() {});
  }

  // ===================== خريطة القاعة =====================

  /// مواقع القاعة: من «عدد الأجنحة المتاحة» مقسوماً على القاعات، أو أعمدة × صفوف
  int? _capacity(int hallsCount) => _maxBooths == null
      ? null
      : (_maxBooths! / (hallsCount < 1 ? 1 : hallsCount)).ceil();

  Widget _map(Map<String, dynamic> hall, List<Map<String, dynamic>> booths,
      List<Map<String, dynamic>> halls) {
    final layout = Map<String, dynamic>.from((hall['map_layout'] ?? {}) as Map);
    final cols = ((layout['cols'] ?? 6) as num).toInt().clamp(2, 12);
    final cap = _capacity(halls.length);
    final rows = cap == null
        ? ((layout['rows'] ?? 4) as num).toInt().clamp(1, 26)
        : (cap / cols).ceil().clamp(1, 26);
    final total = cap == null ? rows * cols : (cap < rows * cols ? cap : rows * cols);
    final bySlot = <String, Map<String, dynamic>>{};
    for (final b in booths.where((b) => b['hall_id'] == hall['id'])) {
      final p = _slot(b['map_slot']);
      if (p != null) bySlot['${p.$1}-${p.$2}'] = b;
    }
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: [
        for (var r = 1; r <= rows; r++)
          for (var c = 1; c <= cols; c++)
            if ((r - 1) * cols + c <= total)
            Builder(builder: (_) {
              final b = bySlot['$r-$c'];
              final code =
                  '${String.fromCharCode(64 + r)}-${c.toString().padLeft(2, '0')}';
              final sponsor = b?['tier'] == 'sponsor';
              return InkWell(
                onTap: b == null ? null : () => _editBooth(b, halls),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: b == null
                        ? kBg
                        : (sponsor ? kBrand.withValues(alpha: 0.06) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: b == null
                            ? kLine
                            : (b['tier'] == 'standard'
                                ? Colors.grey.shade300
                                : kBrand.withValues(alpha: 0.5))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(code,
                          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400)),
                      if (b != null)
                        Text('${b['name']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: kExpoFont,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
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
        final unplaced = booths.where((b) => b['hall_id'] == null || b['map_slot'] == null).toList();
        var slots = 0;
        for (final h in halls) {
          final l = Map<String, dynamic>.from((h['map_layout'] ?? {}) as Map);
          final cap = _capacity(halls.length);
          slots += cap ?? ((l['cols'] ?? 6) as num).toInt() * ((l['rows'] ?? 4) as num).toInt();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            expoHeader('القاعات',
                count: halls.length,
                subtitle:
                    'المواقع في الخرائط: $slots · اضغط أي جناح في الخريطة لتحديد موقعه ونوعه وظهوره',
                actions: [
                  expoButton('قاعة جديدة', () => _editHall(null),
                      primary: true, icon: Icons.add_rounded),
                ]),
            if (halls.isEmpty)
              expoEmpty('لا قاعات بعد', icon: Icons.grid_view_rounded),
            ...halls.map((h) {
              final inHall = booths.where((b) => b['hall_id'] == h['id']).length;
              return ExpoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('${h['name']}',
                          style: const TextStyle(
                              fontFamily: kExpoFont,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      expoStat(Icons.storefront_outlined, '$inHall جناح'),
                      const Spacer(),
                      expoEdit(() => _editHall(h)),
                      if (halls.length > 1) expoDelete(() => _deleteHall(h)),
                    ]),
                    const SizedBox(height: 14),
                    _map(h, booths, halls),
                  ],
                ),
              );
            }),

            const SizedBox(height: 18),
            expoHeader('الأجنحة',
                count: booths.length,
                subtitle: 'تُنشأ الأجنحة عند قبول طلبات العارضين'),
            if (booths.isEmpty)
              expoEmpty('لا أجنحة بعد', icon: Icons.storefront_outlined)
            else ...[
              if (unplaced.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: expoStat(Icons.info_outline_rounded,
                      '${unplaced.length} جناح بدون موقع في الخريطة'),
                ),
              expoGrid(booths.map((b) {
                String hallName = 'بدون قاعة';
                for (final h in halls) {
                  if (h['id'] == b['hall_id']) hallName = '${h['name']}';
                }
                final logo = expoPublicUrl(b['logo_path'] as String?);
                return ExpoCard(
                  onTap: () => _editBooth(b, halls),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kBrand.withValues(alpha: 0.08),
                      backgroundImage: logo != null ? NetworkImage(logo) : null,
                      child: logo == null
                          ? const Icon(Icons.storefront_outlined,
                              color: kBrand, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: kExpoFont,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          expoSub('$hallName · ${b['map_slot'] ?? 'بدون موقع'} · ${kBoothTier['${b['tier']}'] ?? ''}'),
                        ],
                      ),
                    ),
                    expoChip(kBoothStatus['${b['status']}'] ?? '',
                        b['status'] == 'published' ? Colors.green : Colors.grey),
                  ]),
                );
              }).toList()),
            ],
          ],
        );
      },
    );
  }
}
