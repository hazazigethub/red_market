import 'package:flutter/material.dart';
import 'package:red_market_core/red_market_core.dart';

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
      .select('*')
      .eq('exhibition_id', widget.exhibitionId)
      .order('sort_order')
      .order('full_name');

  Future<void> _edit(Map<String, dynamic>? sp) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              _SpeakerEditor(exhibitionId: widget.exhibitionId, speaker: sp)),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> sp) async {
    if (!await expoConfirm(context, 'حذف المتحدث',
        'سيُزال من كل الجلسات المرتبط بها. متابعة؟')) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(
        context, () => expoDb.from('speakers').delete().eq('id', sp['id']),
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
              expoTitle('المتحدثون (${list.length})'),
              const Spacer(),
              expoButton('متحدث جديد', () => _edit(null),
                  primary: true, icon: Icons.add),
            ]),
            if (list.isEmpty) expoEmpty('لا يوجد متحدثون'),
            ...list.map((sp) {
              final photo = expoPublicUrl(sp['photo_path'] as String?);
              return ExpoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.08),
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? Icon(Icons.person, color: AppColors.brand)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${sp['full_name']}',
                            style: const TextStyle(
                                fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
                        expoSub([sp['job_title'], sp['company']]
                            .where((x) => x != null && '$x'.isNotEmpty)
                            .join(' · ')),
                      ],
                    ),
                  ),
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

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return expoToast(context, 'اكتب اسم المتحدث', error: true);
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
        ok: 'تم الحفظ');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return ExpoFormPage(
      title: widget.speaker == null ? 'متحدث جديد' : 'تعديل المتحدث',
      saving: _saving,
      onSave: _save,
      children: [
        ExpoImageField(
            label: 'الصورة',
            prefix: 'exhibitions/${widget.exhibitionId}/speakers',
            initial: _photo,
            onChanged: (p) => _photo = p),
        TextField(controller: _name, decoration: expoInput('الاسم')),
        Row(children: [
          Expanded(
              child: TextField(controller: _job, decoration: expoInput('المسمى الوظيفي'))),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(controller: _company, decoration: expoInput('الجهة'))),
        ]),
        TextField(controller: _bio, maxLines: 4, decoration: expoInput('نبذة')),
        TextField(
            controller: _linkedin,
            textDirection: TextDirection.ltr,
            decoration: expoInput('LinkedIn')),
        TextField(
            controller: _x, textDirection: TextDirection.ltr, decoration: expoInput('X')),
        TextField(
            controller: _website,
            textDirection: TextDirection.ltr,
            decoration: expoInput('الموقع')),
        TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: expoInput('الترتيب')),
      ],
    );
  }
}
