import 'package:flutter/material.dart';

import '../expo_common.dart';

class SessionsTab extends StatefulWidget {
  final String exhibitionId;
  const SessionsTab({super.key, required this.exhibitionId});

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  Future<List<Map<String, dynamic>>> _load() => expoDb
      .from('exhibition_sessions')
      .select('*, session_speakers(speaker_id, role, speakers(full_name)), live_streams(id, status)')
      .eq('exhibition_id', widget.exhibitionId)
      .order('starts_at');

  Future<void> _edit(Map<String, dynamic>? s) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              _SessionEditor(exhibitionId: widget.exhibitionId, session: s)),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _cancel(Map<String, dynamic> s) async {
    if (!await expoConfirm(context, 'إلغاء الجلسة',
        'تبقى ظاهرة في السجل كملغاة، ولا يمكن التسجيل فيها.')) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb
            .from('exhibition_sessions')
            .update({'status': 'cancelled'}).eq('id', s['id']),
        ok: 'تم إلغاء الجلسة');
    if (ok && mounted) setState(() {});
  }

  Future<void> _createStream(Map<String, dynamic> s) async {
    final ok = await expoRun(
        context,
        () => expoDb
            .from('live_streams')
            .insert({'session_id': s['id'], 'title': s['title']}),
        ok: 'تم إنشاء البث. افتح الاستوديو عند موعد الجلسة.');
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
              expoTitle('الجلسات (${list.length})'),
              const Spacer(),
              expoButton('جلسة جديدة', () => _edit(null),
                  primary: true, icon: Icons.add),
            ]),
            if (list.isEmpty) expoEmpty('لا توجد جلسات'),
            ...list.map((s) {
              final speakers = (s['session_speakers'] as List? ?? [])
                  .map((x) => '${x['speakers']?['full_name'] ?? ''}')
                  .where((n) => n.isNotEmpty)
                  .join('، ');
              final streams = s['live_streams'] as List? ?? [];
              final stream = streams.isNotEmpty ? streams.first : null;
              final cancelled = s['status'] == 'cancelled';
              return ExpoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${s['title']}',
                            style: const TextStyle(
                                fontFamily: kExpoFont,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        expoChip(kSessionType['${s['type']}'] ?? '', Colors.blueGrey),
                        if (cancelled) expoChip('ملغاة', Colors.grey),
                        if (s['status'] == 'live') expoChip('مباشر', Colors.red),
                        if (stream != null)
                          expoChip(
                              stream['status'] == 'live' ? 'البث مباشر' : 'بث مُعدّ',
                              Colors.red),
                      ],
                    ),
                    const SizedBox(height: 4),
                    expoSub(
                        '${expoFmtDateTime(s['starts_at'])} — ${expoFmtDateTime(s['ends_at'])}'
                        ' · ${s['registered_count'] ?? 0}${s['capacity'] != null ? '/${s['capacity']}' : ''} مسجل'),
                    if (speakers.isNotEmpty) expoSub('المتحدثون: $speakers'),
                    if (!cancelled) ...[
                      const SizedBox(height: 10),
                      Wrap(runSpacing: 6, children: [
                        expoButton('تعديل', () => _edit(s)),
                        if (stream == null)
                          expoButton('إنشاء بث', () => _createStream(s))
                        else
                          expoButton('فتح استوديو البث', () =>
                              expoOpen('/organizer/e/${widget.exhibitionId}/studio/${stream['id']}'),
                              primary: true, icon: Icons.videocam_outlined),
                        if (s['status'] == 'scheduled')
                          expoButton('إلغاء الجلسة', () => _cancel(s)),
                      ]),
                    ],
                  ],
                ),
              );
            }),
            if (list.any((s) => (s['live_streams'] as List? ?? []).isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: expoSub(
                    'استوديو البث يفتح في المتصفح لأنه يستخدم الكاميرا والميكروفون مباشرة. يلزم تسجيل الدخول في موقع المعارض بحساب الأدمن.'),
              ),
          ],
        );
      },
    );
  }
}

// ===================== محرر الجلسة =====================

class _SessionEditor extends StatefulWidget {
  final String exhibitionId;
  final Map<String, dynamic>? session;
  const _SessionEditor({required this.exhibitionId, this.session});

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _capacity = TextEditingController();
  String _type = 'talk';
  String? _hallId;
  DateTime? _starts;
  DateTime? _ends;
  String? _cover;
  bool _saving = false;
  bool _loading = true;

  List<Map<String, dynamic>> _halls = [];
  List<Map<String, dynamic>> _speakers = [];
  final Map<String, String> _chosen = {}; // speaker_id -> role

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s != null) {
      _title.text = '${s['title'] ?? ''}';
      _desc.text = '${s['description'] ?? ''}';
      _capacity.text = s['capacity'] == null ? '' : '${s['capacity']}';
      _type = '${s['type'] ?? 'talk'}';
      _hallId = s['hall_id'] as String?;
      _starts = expoRiyadh('${s['starts_at']}');
      _ends = expoRiyadh('${s['ends_at']}');
      _cover = s['cover_path'] as String?;
      for (final x in (s['session_speakers'] as List? ?? [])) {
        _chosen['${x['speaker_id']}'] = '${x['role'] ?? 'speaker'}';
      }
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final halls = await expoDb
          .from('exhibition_halls')
          .select('id, name')
          .eq('exhibition_id', widget.exhibitionId)
          .order('sort_order');
      final speakers = await expoDb
          .from('speakers')
          .select('id, full_name, job_title')
          .eq('exhibition_id', widget.exhibitionId)
          .order('sort_order');
      if (mounted) {
        setState(() {
          _halls = halls;
          _speakers = speakers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        expoToast(context, expoError(e), error: true);
      }
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return expoToast(context, 'اكتب عنوان الجلسة', error: true);
    }
    if (_starts == null || _ends == null || !_ends!.isAfter(_starts!)) {
      return expoToast(context, 'حدد بداية ونهاية صحيحتين', error: true);
    }
    final values = {
      'exhibition_id': widget.exhibitionId,
      'title': _title.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'type': _type,
      'hall_id': _hallId,
      'starts_at': expoRiyadhToIso(_starts!),
      'ends_at': expoRiyadhToIso(_ends!),
      'capacity': int.tryParse(_capacity.text.trim()),
      'cover_path': _cover,
    };
    setState(() => _saving = true);
    final ok = await expoRun(context, () async {
      String id;
      if (widget.session == null) {
        final row = await expoDb
            .from('exhibition_sessions')
            .insert(values)
            .select('id')
            .single();
        id = '${row['id']}';
      } else {
        id = '${widget.session!['id']}';
        await expoDb.from('exhibition_sessions').update(values).eq('id', id);
      }
      await expoDb.from('session_speakers').delete().eq('session_id', id);
      if (_chosen.isNotEmpty) {
        await expoDb.from('session_speakers').insert(_chosen.entries
            .map((e) => {'session_id': id, 'speaker_id': e.key, 'role': e.value})
            .toList());
      }
    }, ok: 'تم حفظ الجلسة');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ExpoFormPage(
      title: widget.session == null ? 'جلسة جديدة' : 'تعديل الجلسة',
      saving: _saving,
      onSave: _save,
      children: [
        TextField(controller: _title, decoration: expoInput('العنوان')),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: expoInput('النوع'),
              items: kSessionType.entries
                  .map((t) => DropdownMenuItem(
                      value: t.key,
                      child: Text(t.value,
                          style: const TextStyle(fontFamily: kExpoFont))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'talk'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _hallId,
              decoration: expoInput('القاعة'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('—', style: TextStyle(fontFamily: kExpoFont))),
                ..._halls.map((h) => DropdownMenuItem<String?>(
                    value: '${h['id']}',
                    child: Text('${h['name']}',
                        style: const TextStyle(fontFamily: kExpoFont)))),
              ],
              onChanged: (v) => setState(() => _hallId = v),
            ),
          ),
        ]),
        Row(children: [
          Expanded(
              child: ExpoDateTimeField(
                  label: 'البداية',
                  value: _starts,
                  onChanged: (v) => setState(() => _starts = v))),
          const SizedBox(width: 12),
          Expanded(
              child: ExpoDateTimeField(
                  label: 'النهاية',
                  value: _ends,
                  onChanged: (v) => setState(() => _ends = v))),
        ]),
        TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: expoInput('السعة (اختياري)')),
        TextField(controller: _desc, maxLines: 4, decoration: expoInput('الوصف')),
        ExpoImageField(
            label: 'صورة الجلسة (اختياري)',
            prefix: 'exhibitions/${widget.exhibitionId}/sessions',
            initial: _cover,
            wide: true,
            onChanged: (p) => _cover = p),
        expoTitle('المتحدثون'),
        if (_speakers.isEmpty)
          expoSub('أضف المتحدثين أولاً من تبويب «المتحدثون».')
        else
          ..._speakers.map((sp) {
            final id = '${sp['id']}';
            final on = _chosen.containsKey(id);
            return Row(children: [
              Expanded(
                child: CheckboxListTile(
                  value: on,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('${sp['full_name']}',
                      style: const TextStyle(fontFamily: kExpoFont)),
                  subtitle: sp['job_title'] == null
                      ? null
                      : Text('${sp['job_title']}',
                          style: const TextStyle(fontFamily: kExpoFont)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _chosen[id] = 'speaker';
                    } else {
                      _chosen.remove(id);
                    }
                  }),
                ),
              ),
              if (on)
                Row(children: [
                  Checkbox(
                    value: _chosen[id] == 'moderator',
                    onChanged: (v) => setState(
                        () => _chosen[id] = v == true ? 'moderator' : 'speaker'),
                  ),
                  const Text('مدير الجلسة',
                      style: TextStyle(fontFamily: kExpoFont, fontSize: 12)),
                ]),
            ]);
          }),
      ],
    );
  }
}
