import 'package:flutter/material.dart';
import 'package:red_market_core/red_market_core.dart';

import '../expo_common.dart';

class SponsorsTab extends StatefulWidget {
  final String exhibitionId;
  const SponsorsTab({super.key, required this.exhibitionId});

  @override
  State<SponsorsTab> createState() => _SponsorsTabState();
}

class _SponsorsTabState extends State<SponsorsTab> {
  Future<List<Map<String, dynamic>>> _load() => expoDb
      .from('sponsors')
      .select('*')
      .eq('exhibition_id', widget.exhibitionId)
      .order('tier')
      .order('sort_order');

  Future<void> _edit(Map<String, dynamic>? sp) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              _SponsorEditor(exhibitionId: widget.exhibitionId, sponsor: sp)),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> sp) async {
    if (!await expoConfirm(context, 'حذف الراعي', 'حذف ${sp['name']}؟')) return;
    if (!mounted) return;
    final ok = await expoRun(
        context, () => expoDb.from('sponsors').delete().eq('id', sp['id']),
        ok: 'تم الحذف');
    if (ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final list = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              expoTitle('الرعاة (${list.length})'),
              const Spacer(),
              expoButton('راعٍ جديد', () => _edit(null),
                  primary: true, icon: Icons.add),
            ]),
            if (list.isEmpty) expoEmpty('لا يوجد رعاة'),
            ...list.map((sp) {
              final logo = expoPublicUrl(sp['logo_path'] as String?);
              return ExpoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: logo == null
                        ? Icon(Icons.workspace_premium_outlined,
                            color: AppColors.brand)
                        : Image.network(logo, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${sp['name']}',
                        style: const TextStyle(
                            fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
                  ),
                  expoChip(kSponsorTier['${sp['tier']}'] ?? '', Colors.amber.shade800),
                  const SizedBox(width: 8),
                  expoButton('تعديل', () => _edit(sp)),
                  expoButton('حذف', () => _delete(sp)),
                ]),
              );
            }),
          ],
        );
      },
    );
  }
}

class _SponsorEditor extends StatefulWidget {
  final String exhibitionId;
  final Map<String, dynamic>? sponsor;
  const _SponsorEditor({required this.exhibitionId, this.sponsor});

  @override
  State<_SponsorEditor> createState() => _SponsorEditorState();
}

class _SponsorEditorState extends State<_SponsorEditor> {
  final _name = TextEditingController();
  final _website = TextEditingController();
  final _order = TextEditingController(text: '0');
  String _tier = 'partner';
  String? _boothId;
  String? _logo;
  bool _saving = false;
  List<Map<String, dynamic>> _booths = [];

  @override
  void initState() {
    super.initState();
    final s = widget.sponsor;
    if (s != null) {
      _name.text = '${s['name'] ?? ''}';
      _website.text = '${s['website_url'] ?? ''}';
      _order.text = '${s['sort_order'] ?? 0}';
      _tier = '${s['tier'] ?? 'partner'}';
      _boothId = s['booth_id'] as String?;
      _logo = s['logo_path'] as String?;
    }
    expoDb
        .from('booths')
        .select('id, name')
        .eq('exhibition_id', widget.exhibitionId)
        .order('name')
        .then((v) {
      if (mounted) setState(() => _booths = v);
    }).catchError((_) {});
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return expoToast(context, 'اكتب اسم الراعي', error: true);
    }
    final values = {
      'exhibition_id': widget.exhibitionId,
      'name': _name.text.trim(),
      'tier': _tier,
      'booth_id': _boothId,
      'website_url': _website.text.trim().isEmpty ? null : _website.text.trim(),
      'logo_path': _logo,
      'sort_order': int.tryParse(_order.text) ?? 0,
    };
    setState(() => _saving = true);
    final ok = await expoRun(
        context,
        () => widget.sponsor == null
            ? expoDb.from('sponsors').insert(values)
            : expoDb.from('sponsors').update(values).eq('id', widget.sponsor!['id']),
        ok: 'تم الحفظ');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return ExpoFormPage(
      title: widget.sponsor == null ? 'راعٍ جديد' : 'تعديل الراعي',
      saving: _saving,
      onSave: _save,
      children: [
        ExpoImageField(
            label: 'الشعار',
            prefix: 'exhibitions/${widget.exhibitionId}/sponsors',
            initial: _logo,
            wide: true,
            onChanged: (p) => _logo = p),
        TextField(controller: _name, decoration: expoInput('الاسم')),
        DropdownButtonFormField<String>(
          initialValue: _tier,
          decoration: expoInput('الفئة'),
          items: kSponsorTier.entries
              .map((t) => DropdownMenuItem(
                  value: t.key,
                  child: Text(t.value, style: const TextStyle(fontFamily: kExpoFont))))
              .toList(),
          onChanged: (v) => setState(() => _tier = v ?? 'partner'),
        ),
        DropdownButtonFormField<String?>(
          key: ValueKey('booths-${_booths.length}'),
          // القيمة يجب أن تكون ضمن القائمة، وإلا يتوقف الحقل
          initialValue:
              _booths.any((b) => '${b['id']}' == _boothId) ? _boothId : null,
          decoration: expoInput('جناح الراعي في المعرض (اختياري)'),
          items: [
            const DropdownMenuItem<String?>(
                value: null,
                child: Text('—', style: TextStyle(fontFamily: kExpoFont))),
            ..._booths.map((b) => DropdownMenuItem<String?>(
                value: '${b['id']}',
                child: Text('${b['name']}',
                    style: const TextStyle(fontFamily: kExpoFont)))),
          ],
          onChanged: (v) => setState(() => _boothId = v),
        ),
        TextField(
            controller: _website,
            textDirection: TextDirection.ltr,
            decoration: expoInput('الموقع الإلكتروني', hint: 'https://')),
        TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: expoInput('الترتيب')),
      ],
    );
  }
}
