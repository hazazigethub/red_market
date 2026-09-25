import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:red_market_core/red_market_core.dart';

// =====================================================================
// أدوات مشتركة لشاشات إدارة المعارض (مخطط expo في Supabase)
// =====================================================================

const String kExpoFont = 'Cairo';
const String kExpoSite = 'https://expo.redmarket.pro';

/// قاعدة بيانات المعارض — نفس جلسة الأدمن
final expoDb = Supabase.instance.client.schema('expo');

const Map<String, String> kExhibitionStatus = {
  'draft': 'مسودة',
  'scheduled': 'مجدول',
  'live': 'مباشر',
  'ended': 'انتهى',
  'archived': 'مؤرشف',
};

const Map<String, Color> kExhibitionStatusColor = {
  'draft': Colors.grey,
  'scheduled': Colors.blue,
  'live': Colors.red,
  'ended': Colors.black54,
  'archived': Colors.brown,
};

const Map<String, String> kLocationType = {
  'virtual': 'افتراضي',
  'hybrid': 'هجين',
  'onsite': 'حضوري مع بث',
};

const Map<String, String> kSessionType = {
  'keynote': 'كلمة رئيسية',
  'panel': 'جلسة حوارية',
  'workshop': 'ورشة عمل',
  'talk': 'محاضرة',
};

const Map<String, String> kSponsorTier = {
  'platinum': 'بلاتيني',
  'gold': 'ذهبي',
  'silver': 'فضي',
  'partner': 'شريك',
};

const Map<String, String> kBoothTier = {
  'standard': 'أساسي',
  'premium': 'مميز',
  'sponsor': 'راعٍ',
};

const Map<String, String> kBoothStatus = {
  'draft': 'مسودة',
  'published': 'منشور',
  'hidden': 'مخفي',
};

const Map<String, String> kApplicationStatus = {
  'pending': 'قيد المراجعة',
  'approved': 'مقبول',
  'rejected': 'مرفوض',
  'withdrawn': 'مسحوب',
};

const Map<String, String> kSubscriptionStatus = {
  'ok': 'الاشتراك يغطي المعرض',
  'not_covering': 'الاشتراك ينتهي قبل نهاية المعرض',
  'expired': 'الاشتراك منتهٍ',
  'none': 'غير مشترك',
};

// ===================== الرسائل والأخطاء =====================

void expoToast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: kExpoFont)),
    backgroundColor: error ? Colors.red : Colors.green,
  ));
}

String expoError(Object e) {
  final m = e is PostgrestException ? '${e.message} ${e.details ?? ''}' : '$e';
  const map = {
    'exhibitions_slug_key': 'هذا الرابط مستخدم لمعرض آخر',
    'booths_store_id_fkey': 'لا يمكن حذف عارض لديه أجنحة',
    'exhibitions_organizer_id_fkey': 'لا يمكن حذف جهة لديها معارض',
    'booths_hall_id_map_slot_key': 'هذا الموقع محجوز لجناح آخر في نفس القاعة',
    'exhibitions_check': 'تاريخ النهاية يجب أن يكون بعد البداية',
    'exhibition_sessions_check': 'وقت نهاية الجلسة يجب أن يكون بعد بدايتها',
    'exhibitions_slug_check': 'الرابط: أحرف إنجليزية صغيرة وأرقام وشرطات فقط (3 أحرف على الأقل)',
    'exhibition_halls_exhibition_id_name_key': 'يوجد قاعة بنفس الاسم',
    'INVALID_STATUS_TRANSITION': 'لا يمكن الانتقال إلى هذه الحالة',
    'ORGANIZER_NOT_VERIFIED': 'الجهة المنظمة غير موثّقة',
    'ALREADY_REVIEWED': 'تمت مراجعة هذا الطلب مسبقاً',
    'SUBSCRIPTION_NOT_COVERING': 'اشتراك التاجر ينتهي قبل نهاية المعرض',
    'SUBSCRIPTION_EXPIRED': 'اشتراك التاجر منتهٍ',
    'SUBSCRIPTION_REQUIRED': 'التاجر غير مشترك',
    'STORE_SUSPENDED': 'العارض موقوف من المعارض',
    'STORE_UNAVAILABLE': 'المتجر غير متاح في Red Market',
    'BAD_MESSAGE': 'نص الإعلان بين 2 و280 حرفاً',
    'row-level security': 'ليست لديك صلاحية لهذا الإجراء',
    'permission denied': 'ليست لديك صلاحية لهذا الإجراء',
  };
  for (final entry in map.entries) {
    if (m.contains(entry.key)) return entry.value;
  }
  return 'تعذر الحفظ: $m';
}

/// تنفيذ عملية مع رسالة نجاح/فشل موحّدة. يعيد true عند النجاح.
Future<bool> expoRun(BuildContext context, Future<void> Function() action,
    {String? ok}) async {
  try {
    await action();
    if (context.mounted && ok != null) expoToast(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) expoToast(context, expoError(e), error: true);
    return false;
  }
}

Future<bool> expoConfirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title,
            style: const TextStyle(
                fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(fontFamily: kExpoFont)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: kExpoFont))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('تأكيد', style: TextStyle(fontFamily: kExpoFont)),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

Future<void> expoOpen(String path) async {
  await launchUrl(Uri.parse('$kExpoSite$path'), webOnlyWindowName: '_blank');
}

String? expoPublicUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return Supabase.instance.client.storage.from('expo-public').getPublicUrl(path);
}

// ===================== الوقت (بتوقيت الرياض دائماً) =====================
// الرياض = UTC+3 طوال العام. نتعامل مع "وقت الرياض" ككائن DateTime بقيم الساعة الجدارية.

DateTime expoRiyadh(String iso) =>
    DateTime.parse(iso).toUtc().add(const Duration(hours: 3));

String expoRiyadhToIso(DateTime wall) => DateTime.utc(
        wall.year, wall.month, wall.day, wall.hour, wall.minute)
    .subtract(const Duration(hours: 3))
    .toIso8601String();

String _two(int n) => n.toString().padLeft(2, '0');

String expoFmtDate(dynamic iso) {
  if (iso == null) return '—';
  final d = expoRiyadh('$iso');
  return '${d.day}/${d.month}/${d.year}';
}

String expoFmtDateTime(dynamic iso) {
  if (iso == null) return '—';
  final d = expoRiyadh('$iso');
  return '${d.day}/${d.month}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

// ===================== عناصر الواجهة =====================

class ExpoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const ExpoCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

Widget expoChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: kExpoFont,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color)),
    );

Widget expoButton(String label, VoidCallback? onTap,
        {bool primary = false, IconData? icon}) =>
    Padding(
      padding: const EdgeInsets.only(left: 6),
      child: primary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon ?? Icons.check, size: 16),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0),
              label: Text(label,
                  style: const TextStyle(fontFamily: kExpoFont, fontSize: 12)),
            )
          : OutlinedButton(
              onPressed: onTap,
              child: Text(label,
                  style: const TextStyle(fontFamily: kExpoFont, fontSize: 12)),
            ),
    );

Widget expoTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(text,
          style: const TextStyle(
              fontFamily: kExpoFont, fontSize: 15, fontWeight: FontWeight.bold)),
    );

Widget expoSub(String text) => Text(text,
    style: TextStyle(
        fontFamily: kExpoFont, fontSize: 11.5, color: Colors.grey.shade600));

Widget expoEmpty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: kExpoFont, color: Colors.grey))),
    );

Widget expoLoader() =>
    Center(child: CircularProgressIndicator(color: AppColors.brand));

Widget expoFailed(Object? e) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text('تعذر تحميل البيانات: $e',
          style: const TextStyle(fontFamily: kExpoFont, color: Colors.red)),
    );

InputDecoration expoInput(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontFamily: kExpoFont),
      border: const OutlineInputBorder(),
      isDense: true,
    );

/// نافذة/صفحة بعرض محدود للنماذج
class ExpoFormPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final bool saving;
  const ExpoFormPage(
      {super.key,
      required this.title,
      required this.children,
      required this.onSave,
      this.saving = false});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: Text(title,
              style: const TextStyle(
                  fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 14), child: w)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: saving ? null : onSave,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white),
                      child: Text(saving ? 'جارٍ الحفظ…' : 'حفظ',
                          style: const TextStyle(
                              fontFamily: kExpoFont,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حقل صورة: يرفع الصورة فوراً إلى expo-public ويعيد مسارها
class ExpoImageField extends StatefulWidget {
  final String label;
  final String prefix; // مثل exhibitions/{id}/brand — يحدد صلاحية الرفع
  final String? initial;
  final ValueChanged<String?> onChanged;
  final bool wide;
  const ExpoImageField(
      {super.key,
      required this.label,
      required this.prefix,
      required this.onChanged,
      this.initial,
      this.wide = false});

  @override
  State<ExpoImageField> createState() => _ExpoImageFieldState();
}

class _ExpoImageFieldState extends State<ExpoImageField> {
  String? _path;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _path = widget.initial;
  }

  Future<void> _pick() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) expoToast(context, 'الحد الأقصى 5 ميجابايت', error: true);
        return;
      }
      final name = file.name.toLowerCase();
      final ext = name.endsWith('.png')
          ? 'png'
          : name.endsWith('.webp')
              ? 'webp'
              : 'jpg';
      final path =
          '${widget.prefix}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage.from('expo-public').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                upsert: false,
                contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'),
          );
      setState(() => _path = path);
      widget.onChanged(path);
    } catch (e) {
      if (mounted) expoToast(context, expoError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = expoPublicUrl(_path);
    return Row(
      children: [
        Container(
          width: widget.wide ? 160 : 80,
          height: 80,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: url == null
              ? const Icon(Icons.image_outlined, color: Colors.grey)
              : Image.network(url, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(children: [
                OutlinedButton(
                  onPressed: _busy ? null : _pick,
                  child: Text(
                      _busy
                          ? 'جارٍ الرفع…'
                          : (_path == null ? 'رفع صورة' : 'تغيير'),
                      style: const TextStyle(fontFamily: kExpoFont)),
                ),
                if (_path != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _path = null);
                      widget.onChanged(null);
                    },
                    child: const Text('إزالة',
                        style: TextStyle(
                            fontFamily: kExpoFont, color: Colors.grey)),
                  ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// حقل تاريخ + وقت بتوقيت الرياض
class ExpoDateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value; // وقت الرياض الجداري
  final ValueChanged<DateTime> onChanged;
  const ExpoDateTimeField(
      {super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final base = v ?? DateTime(now.year, now.month, now.day, 10);
        final d = await showDatePicker(
          context: context,
          initialDate: base,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
        );
        if (d == null || !context.mounted) return;
        final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: base.hour, minute: base.minute));
        if (t == null) return;
        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      },
      child: InputDecorator(
        decoration: expoInput('$label (بتوقيت الرياض)'),
        child: Text(
          v == null
              ? 'اختر التاريخ والوقت'
              : '${v.day}/${v.month}/${v.year}  ${_two(v.hour)}:${_two(v.minute)}',
          style: const TextStyle(fontFamily: kExpoFont),
        ),
      ),
    );
  }
}
