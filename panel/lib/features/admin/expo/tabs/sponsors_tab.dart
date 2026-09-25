import 'package:flutter/material.dart';

import '../expo_common.dart';

class SponsorsTab extends StatefulWidget {
  final String exhibitionId;
  const SponsorsTab({super.key, required this.exhibitionId});

  @override
  State<SponsorsTab> createState() => _SponsorsTabState();
}

class _SponsorsTabState extends State<SponsorsTab> {
  static const Map<String, Color> _tierColor = {
    'platinum': Color(0xFF6B7280),
    'gold': Color(0xFFB7791F),
    'silver': Color(0xFF9CA3AF),
    'partner': Colors.blueGrey,
  };

  Future<List<Map<String, dynamic>>> _load() => expoDb
      .from('sponsors')
      .select('*, booths(name)')
      .eq('exhibition_id', widget.exhibitionId)
      .order('tier')
      .order('sort_order');

  Future<void> _edit(Map<String, dynamic>? sp) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _SponsorEditor(exhibitionId: widget.exhibitionId, sponsor: sp));
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> sp) async {
    if (!await expoConfirm(
        context, 'حذف الراعي', 'سيُحذف «${sp['name']}» من رعاة المعرض.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(
        context, () => expoDb.from('sponsors').delete().eq('id', sp['id']),
        ok: 'حُذف الراعي');
    if (ok && mounted) setState(() {});
  }

  Widget _card(Map<String, dynamic> sp) {
    final logo = expoPublicUrl(sp['logo_path'] as String?);
    final tier = '${sp['tier']}';
    final booth = sp['booths'] is Map ? sp['booths']['name'] : null;
    return ExpoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            expoChip(kSponsorTier[tier] ?? tier, _tierColor[tier] ?? Colors.grey),
            const Spacer(),
            expoEdit(() => _edit(sp)),
            expoDelete(() => _delete(sp)),
          ]),
          const SizedBox(height: 10),
          Container(
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(11)),
            child: logo == null
                ? Icon(Icons.workspace_premium_outlined,
                    size: 30, color: Colors.grey.shade300)
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.network(logo, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 10),
          Text('${sp['name']}',
              style: const TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold)),
          if (booth != null || sp['website_url'] != null) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 16, runSpacing: 4, children: [
              if (booth != null) expoStat(Icons.storefront_outlined, '$booth'),
              if (sp['website_url'] != null)
                expoStat(Icons.language_rounded,
                    '${sp['website_url']}'.replaceFirst(RegExp(r'^https?://'), '')),
            ]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final list = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            expoHeader('الرعاة', count: list.length, actions: [
              expoButton('راعٍ جديد', () => _edit(null),
                  primary: true, icon: Icons.add_rounded),
            ]),
            if (list.isEmpty)
              expoEmpty('لا رعاة بعد', icon: Icons.workspace_premium_outlined)
            else
              expoGrid(list.map(_card).toList()),
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
  bool _loading = true;
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
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final booths = await expoDb
          .from('booths')
          .select('id, name')
          .eq('exhibition_id', widget.exhibitionId)
          .order('name');
      if (!mounted) return;
      setState(() {
        _booths = booths;
        // القيمة يجب أن تكون ضمن القائمة
        if (!_booths.any((b) => '${b['id']}' == _boothId)) _boothId = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return expoToast(context, 'اكتب اسم الراعي', warn: true);
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
        ok: widget.sponsor == null ? 'أُضيف الراعي' : 'حُفظ الراعي');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  DropdownMenuItem<T> _item<T>(T value, String label) => DropdownMenuItem<T>(
      value: value,
      child: Text(label, style: const TextStyle(fontFamily: kExpoFont, fontSize: 13)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ExpoDialogLoader();
    return ExpoFormPage(
      title: widget.sponsor == null ? 'راعٍ جديد' : 'تعديل الراعي',
      icon: Icons.workspace_premium_outlined,
      saving: _saving,
      onSave: _save,
      children: [
        TextField(
            controller: _name,
            style: kExpoFieldText,
            decoration: expoInput('اسم الراعي', icon: Icons.title_rounded)),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _tier,
              decoration: expoInput('الفئة', icon: Icons.military_tech_outlined),
              items: kSponsorTier.entries.map((t) => _item(t.key, t.value)).toList(),
              onChanged: (v) => setState(() => _tier = v ?? 'partner'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                style: kExpoFieldText,
                decoration: expoInput('ترتيب الظهور', icon: Icons.sort_rounded)),
          ),
        ]),
        DropdownButtonFormField<String?>(
          initialValue: _boothId,
          decoration: expoInput('جناحه في المعرض — اختياري',
              icon: Icons.storefront_outlined),
          items: [
            _item<String?>(null, '—'),
            ..._booths.map((b) => _item<String?>('${b['id']}', '${b['name']}')),
          ],
          onChanged: (v) => setState(() => _boothId = v),
        ),
        TextField(
            controller: _website,
            textDirection: TextDirection.ltr,
            style: kExpoFieldText,
            decoration: expoInput('الموقع الإلكتروني',
                hint: 'https://', icon: Icons.language_rounded)),
        expoFormSection('الشعار', Icons.image_outlined, note: 'PNG بخلفية شفافة'),
        ExpoImageField(
            label: 'الشعار',
            prefix: 'exhibitions/${widget.exhibitionId}/sponsors',
            initial: _logo,
            wide: true,
            onChanged: (p) => _logo = p),
      ],
    );
  }
}
