import 'package:flutter/material.dart';

import 'expo_common.dart';

/// نافذة إنشاء معرض أو تعديله. تُفتح بـ showDialog وتعيد true عند الحفظ.
class ExpoExhibitionFormPage extends StatefulWidget {
  final Map<String, dynamic>? exhibition; // null = معرض جديد
  const ExpoExhibitionFormPage({super.key, this.exhibition});

  @override
  State<ExpoExhibitionFormPage> createState() => _ExpoExhibitionFormPageState();
}

class _ExpoExhibitionFormPageState extends State<ExpoExhibitionFormPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _venue = TextEditingController();
  final _city = TextEditingController();

  String? _organizerId;
  int? _categoryId;
  String _locationType = 'virtual';
  DateTime? _starts;
  DateTime? _ends;
  String? _logo;
  String? _cover;
  bool _applicationsOpen = true;
  bool _chatEnabled = true;
  bool _saving = false;

  List<Map<String, dynamic>> _organizers = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  bool get _isNew => widget.exhibition == null;

  @override
  void initState() {
    super.initState();
    final e = widget.exhibition;
    if (e != null) {
      _title.text = '${e['title'] ?? ''}';
      _desc.text = '${e['description'] ?? ''}';
      _venue.text = '${e['venue'] ?? ''}';
      _city.text = '${e['city'] ?? ''}';
      _organizerId = e['organizer_id'] as String?;
      _categoryId = (e['category_id'] as num?)?.toInt();
      _locationType = '${e['location_type'] ?? 'virtual'}';
      _starts = e['starts_at'] == null ? null : expoRiyadh('${e['starts_at']}');
      _ends = e['ends_at'] == null ? null : expoRiyadh('${e['ends_at']}');
      _logo = e['logo_path'] as String?;
      _cover = e['cover_path'] as String?;
      _applicationsOpen = e['applications_open'] != false;
      _chatEnabled = e['chat_enabled'] != false;
    }
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _venue.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orgs = await expoDb
          .from('organizers')
          .select('id, name, is_verified, is_suspended')
          .order('name');
      final cats = await expoDb
          .from('exhibition_categories')
          .select('id, name_ar')
          .order('id');
      if (!mounted) return;
      setState(() {
        _organizers = orgs;
        _categories = cats;
        _organizerId ??= orgs.isNotEmpty ? '${orgs.first['id']}' : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        expoToast(context, expoError(e), error: true);
      }
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      return expoToast(context, 'اكتب اسم المعرض', warn: true);
    }
    if (_organizerId == null) {
      return expoToast(context, 'أنشئ جهة منظمة أولاً', warn: true);
    }
    if (_starts == null || _ends == null) {
      return expoToast(context, 'حدّد موعد البداية والنهاية', warn: true);
    }
    if (!_ends!.isAfter(_starts!)) {
      return expoToast(context, 'موعد النهاية قبل البداية', warn: true);
    }

    final values = <String, dynamic>{
      'organizer_id': _organizerId,
      'title': _title.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'category_id': _categoryId,
      'location_type': _locationType,
      'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'starts_at': expoRiyadhToIso(_starts!),
      'ends_at': expoRiyadhToIso(_ends!),
      'logo_path': _logo,
      'cover_path': _cover,
      'applications_open': _applicationsOpen,
      'chat_enabled': _chatEnabled,
    };

    setState(() => _saving = true);
    final ok = await expoRun(context, () async {
      if (_isNew) {
        // الرابط يُولَّد تلقائياً في قاعدة البيانات
        final row =
            await expoDb.from('exhibitions').insert(values).select('id').single();
        await expoDb
            .from('exhibition_halls')
            .insert({'exhibition_id': row['id'], 'name': 'القاعة الرئيسية'});
      } else {
        await expoDb
            .from('exhibitions')
            .update(values)
            .eq('id', widget.exhibition!['id']);
      }
    }, ok: _isNew ? 'أُنشئ المعرض كمسودة' : 'حُفظ المعرض');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  DropdownMenuItem<T> _item<T>(T value, String label) => DropdownMenuItem<T>(
      value: value,
      child: Text(label,
          style: const TextStyle(fontFamily: kExpoFont, fontSize: 13)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ExpoDialogLoader();

    // الصور قبل إنشاء المعرض تُرفع في مجلد الجهة المنظمة
    final prefix = _isNew
        ? 'organizers/${_organizerId ?? 'none'}/brand'
        : 'exhibitions/${widget.exhibition!['id']}/brand';

    return ExpoFormPage(
      title: _isNew ? 'معرض جديد' : 'تعديل المعرض',
      icon: Icons.event_available_outlined,
      saving: _saving,
      onSave: _save,
      maxWidth: 560,
      children: [
        if (_organizers.isEmpty)
          expoSub('لا توجد جهة منظمة. أنشئ واحدة من زر «جهة منظمة» أولاً.')
        else
          DropdownButtonFormField<String>(
            initialValue: _organizerId,
            decoration: expoInput('الجهة المنظمة', icon: Icons.apartment_outlined),
            items: _organizers
                .map((o) => _item('${o['id']}',
                    '${o['name']}${o['is_verified'] == true ? '' : ' (غير موثّقة)'}'))
                .toList(),
            onChanged: (v) => setState(() => _organizerId = v),
          ),
        TextField(
            controller: _title,
            style: kExpoFieldText,
            decoration: expoInput('اسم المعرض', icon: Icons.title_rounded)),
        TextField(
            controller: _desc,
            maxLines: 3,
            style: kExpoFieldText,
            decoration: expoInput('الوصف', icon: Icons.notes_rounded)),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: expoInput('التصنيف', icon: Icons.category_outlined),
              items: _categories
                  .map((c) => _item((c['id'] as num).toInt(), '${c['name_ar']}'))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _locationType,
              decoration: expoInput('النوع', icon: Icons.videocam_outlined),
              items: kLocationType.entries.map((e) => _item(e.key, e.value)).toList(),
              onChanged: (v) => setState(() => _locationType = v ?? 'virtual'),
            ),
          ),
        ]),
        if (_locationType != 'virtual')
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _venue,
                    style: kExpoFieldText,
                    decoration: expoInput('المكان', icon: Icons.place_outlined))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _city,
                    style: kExpoFieldText,
                    decoration:
                        expoInput('المدينة', icon: Icons.location_city_outlined))),
          ]),

        // ===== الموعد =====
        expoFormSection('الموعد', Icons.schedule_rounded, note: 'بتوقيت الرياض'),
        Row(children: [
          Expanded(
              child: ExpoDateTimeField(
                  label: 'يبدأ',
                  value: _starts,
                  onChanged: (v) => setState(() => _starts = v))),
          const SizedBox(width: 10),
          Expanded(
              child: ExpoDateTimeField(
                  label: 'ينتهي',
                  value: _ends,
                  onChanged: (v) => setState(() => _ends = v))),
        ]),

        // ===== الهوية =====
        expoFormSection('الشعار', Icons.image_outlined, note: 'مربع · 512 × 512'),
        ExpoImageField(
            key: ValueKey('logo-$prefix'),
            label: 'الشعار',
            prefix: prefix,
            initial: _logo,
            onChanged: (p) => _logo = p),
        expoFormSection('صورة الغلاف', Icons.panorama_outlined,
            note: '1920 × 800'),
        ExpoImageField(
            key: ValueKey('cover-$prefix'),
            label: 'صورة الغلاف',
            prefix: prefix,
            initial: _cover,
            wide: true,
            onChanged: (p) => _cover = p),

        // ===== الإعدادات =====
        expoFormSection('الإعدادات', Icons.tune_rounded),
        Column(children: [
          expoSwitch('استقبال طلبات مشاركة العارضين', _applicationsOpen,
              (v) => setState(() => _applicationsOpen = v)),
          expoSwitch('المحادثات بين الزوار والعارضين', _chatEnabled,
              (v) => setState(() => _chatEnabled = v)),
        ]),
      ],
    );
  }
}
