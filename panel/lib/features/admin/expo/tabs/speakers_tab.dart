import 'package:flutter/material.dart';

import '../expo_common.dart';

class SpeakersTab extends StatefulWidget {
  final String exhibitionId;
  const SpeakersTab({super.key, required this.exhibitionId});

  @override
  State<SpeakersTab> createState() => _SpeakersTabState();
}

class _SpeakersTabState extends State<SpeakersTab> {
  Future<List<Map<String, dynamic>>> _load() => expoDb
      .from('speakers')
      .select('*, session_speakers(count)')
      .eq('exhibition_id', widget.exhibitionId)
      .order('sort_order')
      .order('full_name');

  Future<void> _edit(Map<String, dynamic>? sp) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _SpeakerEditor(exhibitionId: widget.exhibitionId, speaker: sp));
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> sp) async {
    if (!await expoConfirm(context, 'حذف المتحدث',
        'سيُحذف «${sp['full_name']}» ويُزال من كل الجلسات المرتبط بها.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(
        context, () => expoDb.from('speakers').delete().eq('id', sp['id']),
        ok: 'حُذف المتحدث');
    if (ok && mounted) setState(() {});
  }

  Widget _card(Map<String, dynamic> sp) {
    final photo = expoPublicUrl(sp['photo_path'] as String?);
    final sessions = (sp['session_speakers'] is List &&
            (sp['session_speakers'] as List).isNotEmpty)
        ? (sp['session_speakers'] as List).first['count']
        : 0;
    final role = [sp['job_title'], sp['company']]
        .where((x) => x != null && '$x'.isNotEmpty)
        .join(' · ');
    return ExpoCard(
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: kBrand.withValues(alpha: 0.08),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? const Icon(Icons.person_outline_rounded, color: kBrand)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${sp['full_name']}',
                  style: const TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold)),
              if (role.isNotEmpty) ...[
                const SizedBox(height: 2),
                expoSub(role),
              ],
              const SizedBox(height: 6),
              expoStat(Icons.mic_none_rounded, '$sessions جلسة'),
            ],
          ),
        ),
        expoEdit(() => _edit(sp)),
        expoDelete(() => _delete(sp)),
      ]),
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
            expoHeader('المتحدثون', count: list.length, actions: [
              expoButton('متحدث جديد', () => _edit(null),
                  primary: true, icon: Icons.add_rounded),
            ]),
            if (list.isEmpty)
              expoEmpty('لا متحدثين بعد', icon: Icons.record_voice_over_outlined)
            else
              expoGrid(list.map(_card).toList()),
          ],
        );
      },
    );
  }
}

class _SpeakerEditor extends StatefulWidget {
  final String exhibitionId;
  final Map<String, dynamic>? speaker;
  const _SpeakerEditor({required this.exhibitionId, this.speaker});

  @override
  State<_SpeakerEditor> createState() => _SpeakerEditorState();
}

class _SpeakerEditorState extends State<_SpeakerEditor> {
  final _name = TextEditingController();
  final _job = TextEditingController();
  final _company = TextEditingController();
  final _bio = TextEditingController();
  final _linkedin = TextEditingController();
  final _x = TextEditingController();
  final _website = TextEditingController();
  final _order = TextEditingController(text: '0');
  String? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.speaker;
    if (s != null) {
      final links = Map<String, dynamic>.from((s['links'] ?? {}) as Map);
      _name.text = '${s['full_name'] ?? ''}';
      _job.text = '${s['job_title'] ?? ''}';
      _company.text = '${s['company'] ?? ''}';
      _bio.text = '${s['bio'] ?? ''}';
      _linkedin.text = '${links['linkedin'] ?? ''}';
      _x.text = '${links['x'] ?? ''}';
      _website.text = '${links['website'] ?? ''}';
      _order.text = '${s['sort_order'] ?? 0}';
      _photo = s['photo_path'] as String?;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _job, _company, _bio, _linkedin, _x, _website, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return expoToast(context, 'اكتب اسم المتحدث', warn: true);
    }
    final links = <String, String>{};
    if (_v(_linkedin) != null) links['linkedin'] = _v(_linkedin)!;
    if (_v(_x) != null) links['x'] = _v(_x)!;
    if (_v(_website) != null) links['website'] = _v(_website)!;
    final values = {
      'exhibition_id': widget.exhibitionId,
      'full_name': _name.text.trim(),
      'job_title': _v(_job),
      'company': _v(_company),
      'bio': _v(_bio),
      'photo_path': _photo,
      'links': links,
      'sort_order': int.tryParse(_order.text) ?? 0,
    };
    setState(() => _saving = true);
    final ok = await expoRun(
        context,
        () => widget.speaker == null
            ? expoDb.from('speakers').insert(values)
            : expoDb.from('speakers').update(values).eq('id', widget.speaker!['id']),
        ok: widget.speaker == null ? 'أُضيف المتحدث' : 'حُفظ المتحدث');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return ExpoFormPage(
      title: widget.speaker == null ? 'متحدث جديد' : 'تعديل المتحدث',
      icon: Icons.record_voice_over_outlined,
      saving: _saving,
      onSave: _save,
      children: [
        TextField(
            controller: _name,
            style: kExpoFieldText,
            decoration: expoInput('الاسم', icon: Icons.person_outline_rounded)),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _job,
                  style: kExpoFieldText,
                  decoration: expoInput('المسمى الوظيفي', icon: Icons.badge_outlined))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _company,
                  style: kExpoFieldText,
                  decoration: expoInput('الجهة', icon: Icons.apartment_outlined))),
        ]),
        TextField(
            controller: _bio,
            maxLines: 3,
            style: kExpoFieldText,
            decoration: expoInput('نبذة', icon: Icons.notes_rounded)),
        expoFormSection('الصورة', Icons.image_outlined, note: 'مربعة'),
        ExpoImageField(
            label: 'الصورة',
            prefix: 'exhibitions/${widget.exhibitionId}/speakers',
            initial: _photo,
            onChanged: (p) => _photo = p),
        expoFormSection('الروابط', Icons.link_rounded, note: 'اختيارية'),
        TextField(
            controller: _linkedin,
            textDirection: TextDirection.ltr,
            style: kExpoFieldText,
            decoration: expoInput('LinkedIn', icon: Icons.work_outline_rounded)),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _x,
                  textDirection: TextDirection.ltr,
                  style: kExpoFieldText,
                  decoration: expoInput('X', icon: Icons.alternate_email_rounded))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _website,
                  textDirection: TextDirection.ltr,
                  style: kExpoFieldText,
                  decoration: expoInput('الموقع', icon: Icons.language_rounded))),
        ]),
        TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            style: kExpoFieldText,
            decoration: expoInput('ترتيب الظهور', icon: Icons.sort_rounded)),
      ],
    );
  }
}
