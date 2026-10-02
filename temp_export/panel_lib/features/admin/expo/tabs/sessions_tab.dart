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
      .select(
          '*, session_speakers(speaker_id, role, speakers(full_name)), live_streams(id, status)')
      .eq('exhibition_id', widget.exhibitionId)
      .order('starts_at');

  Future<void> _edit(Map<String, dynamic>? s) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _SessionEditor(exhibitionId: widget.exhibitionId, session: s));
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _cancel(Map<String, dynamic> s) async {
    if (!await expoConfirm(context, 'إلغاء الجلسة',
        'تبقى «${s['title']}» ظاهرة في الأجندة كملغاة، ولا يمكن التسجيل فيها.',
        confirmLabel: 'إلغاء الجلسة')) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(
        context,
        () => expoDb
            .from('exhibition_sessions')
            .update({'status': 'cancelled'}).eq('id', s['id']),
        ok: 'أُلغيت الجلسة');
    if (ok && mounted) setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    if (!await expoConfirm(context, 'حذف الجلسة',
        'ستُحذف «${s['title']}» نهائياً مع تسجيلات الحضور.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb.from('exhibition_sessions').delete().eq('id', s['id']),
        ok: 'حُذفت الجلسة');
    if (ok && mounted) setState(() {});
  }

  Future<void> _createStream(Map<String, dynamic> s) async {
    final ok = await expoRun(
        context,
        () => expoDb
            .from('live_streams')
            .insert({'session_id': s['id'], 'title': s['title']}),
        ok: 'جُهّز البث. افتح الاستوديو عند موعد الجلسة');
    if (ok && mounted) setState(() {});
  }

  Widget _card(Map<String, dynamic> s) {
    final speakers = (s['session_speakers'] as List? ?? [])
        .map((x) => '${x['speakers']?['full_name'] ?? ''}')
        .where((n) => n.isNotEmpty)
        .join('، ');
    final streams = s['live_streams'] as List? ?? [];
    final stream = streams.isNotEmpty ? streams.first : null;
    final status = '${s['status']}';
    final cancelled = status == 'cancelled';
    final (String label, Color color) = switch (status) {
      'live' => ('مباشرة', Colors.green),
      'ended' => ('انتهت', Colors.orange),
      'cancelled' => ('ملغاة', Colors.grey),
      _ => ('مجدولة', Colors.blue),
    };

    return ExpoCard(
      borderColor: status == 'live' ? Colors.green.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s['title']}',
                      style: TextStyle(
                          fontFamily: kExpoFont,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          decoration: cancelled ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 4),
                  Text(
                      '${expoFmtDateTime(s['starts_at'])} — ${expoFmtDateTime(s['ends_at']).split(' ').last}',
                      style: TextStyle(
                          fontFamily: kExpoFont,
                          fontSize: 11.5,
                          color: Colors.grey.shade600)),
                ],
              ),
            ),
            expoChip(label, color),
            const SizedBox(width: 6),
            if (!cancelled) expoEdit(() => _edit(s)),
            expoDelete(() => _delete(s)),
          ]),
          const SizedBox(height: 12),
          kExpoDivider,
          const SizedBox(height: 10),
          Wrap(spacing: 18, runSpacing: 6, children: [
            expoStat(Icons.category_outlined, kSessionType['${s['type']}'] ?? ''),
            expoStat(Icons.people_outline_rounded,
                s['capacity'] != null
                    ? '${expoOf(s['registered_count'] ?? 0, s['capacity'])} مسجل'
                    : '${s['registered_count'] ?? 0} مسجل'),
            if (speakers.isNotEmpty)
              expoStat(Icons.record_voice_over_outlined, speakers),
          ]),
          if (!cancelled) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (status == 'scheduled')
                TextButton(
                  onPressed: () => _cancel(s),
                  child: Text('إلغاء الجلسة',
                      style: TextStyle(
                          fontFamily: kExpoFont,
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                ),
              const Spacer(),
              if (stream == null)
                expoButton('تجهيز بث', () => _createStream(s),
                    icon: Icons.videocam_outlined)
              else
                expoButton(
                    stream['status'] == 'live' ? 'البث مباشر · الاستوديو' : 'فتح الاستوديو',
                    () => expoOpen(
                        '/organizer/e/${widget.exhibitionId}/studio/${stream['id']}'),
                    primary: true,
                    icon: Icons.videocam_rounded),
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
            expoHeader('الجلسات',
                count: list.length,
                subtitle:
                    'استوديو البث يفتح في المتصفح لأنه يستخدم الكاميرا والميكروفون — ادخل موقع المعارض بحساب الأدمن',
                actions: [
                  expoButton('جلسة جديدة', () => _edit(null),
                      primary: true, icon: Icons.add_rounded),
                ]),
            if (list.isEmpty)
              expoEmpty('لا جلسات بعد', icon: Icons.mic_none_rounded)
            else
              expoGrid(list.map(_card).toList(), maxCols: 2),
          ],
        );
      },
    );
  }
}

// ===================== نافذة الجلسة =====================

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

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _capacity.dispose();
    super.dispose();
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
      return expoToast(context, 'اكتب عنوان الجلسة', warn: true);
    }
    if (_starts == null || _ends == null) {
      return expoToast(context, 'حدّد البداية والنهاية', warn: true);
    }
    if (!_ends!.isAfter(_starts!)) {
      return expoToast(context, 'النهاية قبل البداية', warn: true);
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
    }, ok: widget.session == null ? 'أُضيفت الجلسة' : 'حُفظت الجلسة');
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
      title: widget.session == null ? 'جلسة جديدة' : 'تعديل الجلسة',
      icon: Icons.mic_none_rounded,
      saving: _saving,
      onSave: _save,
      children: [
        TextField(
            controller: _title,
            style: kExpoFieldText,
            decoration: expoInput('عنوان الجلسة', icon: Icons.title_rounded)),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: expoInput('النوع', icon: Icons.category_outlined),
              items: kSessionType.entries.map((t) => _item(t.key, t.value)).toList(),
              onChanged: (v) => setState(() => _type = v ?? 'talk'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _hallId,
              decoration: expoInput('القاعة', icon: Icons.grid_view_rounded),
              items: [
                _item<String?>(null, '—'),
                ..._halls.map((h) => _item<String?>('${h['id']}', '${h['name']}')),
              ],
              onChanged: (v) => setState(() => _hallId = v),
            ),
          ),
        ]),
        expoFormSection('الموعد', Icons.schedule_rounded, note: 'بتوقيت الرياض'),
        Row(children: [
          Expanded(
              child: ExpoDateTimeField(
                  label: 'تبدأ',
                  value: _starts,
                  onChanged: (v) => setState(() => _starts = v))),
          const SizedBox(width: 10),
          Expanded(
              child: ExpoDateTimeField(
                  label: 'تنتهي',
                  value: _ends,
                  onChanged: (v) => setState(() => _ends = v))),
        ]),
        TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            style: kExpoFieldText,
            decoration: expoInput('السعة — اتركها فارغة بلا حد',
                icon: Icons.people_outline_rounded)),
        TextField(
            controller: _desc,
            maxLines: 3,
            style: kExpoFieldText,
            decoration: expoInput('الوصف', icon: Icons.notes_rounded)),
        expoFormSection('صورة الجلسة', Icons.image_outlined, note: 'اختيارية'),
        ExpoImageField(
            label: 'صورة الجلسة',
            prefix: 'exhibitions/${widget.exhibitionId}/sessions',
            initial: _cover,
            wide: true,
            onChanged: (p) => _cover = p),
        expoFormSection('المتحدثون', Icons.record_voice_over_outlined),
        if (_speakers.isEmpty)
          expoSub('أضف المتحدثين أولاً من تبويب «المتحدثون».')
        else
          Container(
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: _speakers.map((sp) {
                final id = '${sp['id']}';
                final on = _chosen.containsKey(id);
                return Row(children: [
                  Checkbox(
                    value: on,
                    activeColor: kBrand,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _chosen[id] = 'speaker';
                      } else {
                        _chosen.remove(id);
                      }
                    }),
                  ),
                  Expanded(
                    child: Text(
                        '${sp['full_name']}${sp['job_title'] != null ? ' · ${sp['job_title']}' : ''}',
                        style: const TextStyle(fontFamily: kExpoFont, fontSize: 12.5)),
                  ),
                  if (on) ...[
                    Text('مدير الجلسة',
                        style: TextStyle(
                            fontFamily: kExpoFont,
                            fontSize: 11,
                            color: Colors.grey.shade600)),
                    Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: _chosen[id] == 'moderator',
                        activeTrackColor: Colors.green,
                        onChanged: (v) => setState(
                            () => _chosen[id] = v ? 'moderator' : 'speaker'),
                      ),
                    ),
                  ],
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }
}
