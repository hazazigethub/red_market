import 'package:flutter/material.dart';

import 'expo_common.dart';

/// إنشاء معرض أو تعديله. يعيد true عند الحفظ.
class ExpoExhibitionFormPage extends StatefulWidget {
  final Map<String, dynamic>? exhibition; // null = معرض جديد
  const ExpoExhibitionFormPage({super.key, this.exhibition});

  @override
  State<ExpoExhibitionFormPage> createState() => _ExpoExhibitionFormPageState();
}

class _ExpoExhibitionFormPageState extends State<ExpoExhibitionFormPage> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
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
      _slug.text = '${e['slug'] ?? ''}';
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

  Future<void> _load() async {
    try {
      final orgs = await expoDb
          .from('organizers')
          .select('id, name, is_verified, is_suspended')
          .order('name');
      final cats =
          await expoDb.from('exhibition_categories').select('id, name_ar').order('id');
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
    final slug = _slug.text.trim().toLowerCase();
    if (_title.text.trim().length < 3) {
      return expoToast(context, 'اسم المعرض 3 أحرف على الأقل', error: true);
    }
    if (_isNew && !RegExp(r'^[a-z0-9][a-z0-9-]{1,78}[a-z0-9]$').hasMatch(slug)) {
      return expoToast(context,
          'الرابط: أحرف إنجليزية صغيرة وأرقام وشرطات فقط، مثل coffee-expo-2026',
          error: true);
    }
    if (_organizerId == null) {
      return expoToast(context, 'أنشئ جهة منظمة أولاً', error: true);
    }
    if (_starts == null || _ends == null) {
      return expoToast(context, 'حدد موعد البداية والنهاية', error: true);
    }
    if (!_ends!.isAfter(_starts!)) {
      return expoToast(context, 'النهاية يجب أن تكون بعد البداية', error: true);
    }

    final values = <String, dynamic>{
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
        final row = await expoDb
            .from('exhibitions')
            .insert({...values, 'organizer_id': _organizerId, 'slug': slug})
            .select('id')
            .single();
        // قاعة افتراضية لكل معرض جديد
        await expoDb
            .from('exhibition_halls')
            .insert({'exhibition_id': row['id'], 'name': 'القاعة الرئيسية'});
      } else {
        await expoDb
            .from('exhibitions')
            .update({...values, 'organizer_id': _organizerId})
            .eq('id', widget.exhibition!['id']);
      }
    }, ok: _isNew ? 'تم إنشاء المعرض كمسودة' : 'تم حفظ التعديلات');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // الصور قبل إنشاء المعرض تُرفع في مجلد الجهة المنظمة
    final prefix = _isNew
        ? 'organizers/${_organizerId ?? 'none'}/brand'
        : 'exhibitions/${widget.exhibition!['id']}/brand';

    return ExpoFormPage(
      title: _isNew ? 'معرض جديد' : 'تعديل المعرض',
      saving: _saving,
      onSave: _save,
      children: [
        if (_organizers.isEmpty)
          expoSub('لا توجد جهة منظمة. أنشئ واحدة من زر «منظم جديد» أولاً.')
        else
          DropdownButtonFormField<String>(
            initialValue: _organizerId,
            decoration: expoInput('الجهة المنظمة'),
            items: _organizers
                .map((o) => DropdownMenuItem(
                    value: '${o['id']}',
                    child: Text(
                        '${o['name']}${o['is_verified'] == true ? '' : ' (غير موثّقة)'}',
                        style: const TextStyle(fontFamily: kExpoFont))))
                .toList(),
            onChanged: (v) => setState(() => _organizerId = v),
          ),
        TextField(controller: _title, decoration: expoInput('اسم المعرض')),
        if (_isNew)
          TextField(
            controller: _slug,
            textDirection: TextDirection.ltr,
            decoration: expoInput('الرابط المختصر',
                hint: 'coffee-expo-2026  ←  expo.redmarket.pro/e/coffee-expo-2026'),
          )
        else
          expoSub('الرابط: expo.redmarket.pro/e/${_slug.text}'),
        TextField(
            controller: _desc,
            maxLines: 5,
            decoration: expoInput('الوصف')),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: expoInput('التصنيف'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                      value: (c['id'] as num).toInt(),
                      child: Text('${c['name_ar']}',
                          style: const TextStyle(fontFamily: kExpoFont))))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _locationType,
              decoration: expoInput('النوع'),
              items: kLocationType.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value,
                          style: const TextStyle(fontFamily: kExpoFont))))
                  .toList(),
              onChanged: (v) => setState(() => _locationType = v ?? 'virtual'),
            ),
          ),
        ]),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _venue,
                  decoration: expoInput('المكان (للحضوري/الهجين)'))),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(controller: _city, decoration: expoInput('المدينة'))),
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
        ExpoImageField(
            key: ValueKey('logo-$prefix'),
            label: 'الشعار (مربع)',
            prefix: prefix,
            initial: _logo,
            onChanged: (p) => _logo = p),
        ExpoImageField(
            key: ValueKey('cover-$prefix'),
            label: 'صورة الغلاف (1920×800)',
            prefix: prefix,
            initial: _cover,
            wide: true,
            onChanged: (p) => _cover = p),
        SwitchListTile(
          value: _applicationsOpen,
          onChanged: (v) => setState(() => _applicationsOpen = v),
          title: const Text('استقبال طلبات مشاركة العارضين',
              style: TextStyle(fontFamily: kExpoFont)),
        ),
        SwitchListTile(
          value: _chatEnabled,
          onChanged: (v) => setState(() => _chatEnabled = v),
          title: const Text('تفعيل المحادثات بين الزوار والعارضين',
              style: TextStyle(fontFamily: kExpoFont)),
        ),
      ],
    );
  }
}
