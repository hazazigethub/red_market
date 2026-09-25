import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// =====================================================================
// أدوات مشتركة لقسم المعارض — مطابقة لنظام تصميم لوحة الأدمن
// (brandRed D32027، الخلفية F7F8FA، الحدود EDEFF3، خط Cairo، نوافذ منبثقة)
// =====================================================================

const String kExpoFont = 'Cairo';
const String kExpoSite = 'https://expo.redmarket.pro';

const Color kBrand = Color(0xFFD32027);
const Color kBg = Color(0xFFF7F8FA);
const Color kLine = Color(0xFFEDEFF3);
const Color kInk = Color(0xFF1F2937);

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
  'live': Colors.green,
  'ended': Colors.orange,
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

void expoToast(BuildContext context, String msg,
    {bool error = false, bool warn = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: kExpoFont)),
    backgroundColor: error ? Colors.red : (warn ? Colors.orange : Colors.green),
  ));
}

String expoError(Object e) {
  final m = e is PostgrestException ? '${e.message} ${e.details ?? ''}' : '$e';
  const map = {
    'booths_store_id_fkey': 'لا يمكن حذف عارض لديه أجنحة. احذف أجنحته أولاً، أو أوقفه.',
    'exhibitions_organizer_id_fkey': 'لا يمكن حذف جهة لديها معارض. احذف معارضها أولاً، أو أوقفها.',
    'exhibitions_slug_key': 'هذا الرابط مستخدم لمعرض آخر',
    'booths_hall_id_map_slot_key': 'هذا الموقع محجوز لجناح آخر في نفس القاعة',
    'exhibitions_check': 'تاريخ النهاية يجب أن يكون بعد البداية',
    'exhibition_sessions_check': 'وقت نهاية الجلسة يجب أن يكون بعد بدايتها',
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
    'EXHIBITION_FULL': 'اكتمل عدد الأجنحة في هذا المعرض. زِد العدد من «تعديل المعرض» لقبول المزيد.',
    'max_booths_check': 'عدد الأجنحة يجب أن يكون 1 أو أكثر',
    'row-level security': 'ليست لديك صلاحية لهذا الإجراء',
    'permission denied': 'ليست لديك صلاحية لهذا الإجراء',
  };
  for (final entry in map.entries) {
    if (m.contains(entry.key)) return entry.value;
  }
  debugPrint('Expo error: $m');
  return 'تعذر تنفيذ العملية';
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

/// نافذة تأكيد — danger للحذف (زر أحمر وأيقونة حذف)
Future<bool> expoConfirm(BuildContext context, String title, String body,
    {bool danger = false, String? confirmLabel}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
              color: danger ? Colors.red : kBrand, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: kExpoFont,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(body,
              style: const TextStyle(
                  fontFamily: kExpoFont, fontSize: 13.5, height: 1.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع',
                style: TextStyle(fontFamily: kExpoFont, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? Colors.red : kBrand,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? (danger ? 'حذف نهائي' : 'تأكيد'),
                style: const TextStyle(
                    fontFamily: kExpoFont,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
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

// ===================== تخطيط الصفحة =====================

/// محتوى الصفحة بعرض محدود وتوسيط، مثل بقية صفحات اللوحة
class ExpoPage extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const ExpoPage({super.key, required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final list = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: kBrand, child: list);
  }
}

/// رأس القسم: العنوان + العدد + الأزرار + سطر توضيحي
Widget expoHeader(String title,
    {int? count, String? subtitle, List<Widget> actions = const []}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Flexible(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: kExpoFont,
                    fontSize: 19,
                    fontWeight: FontWeight.bold)),
          ),
          if (count != null) ...[
            const SizedBox(width: 10),
            Text('$count',
                style: TextStyle(
                    fontFamily: kExpoFont,
                    fontSize: 13,
                    color: Colors.grey.shade500)),
          ],
          const Spacer(),
          ...actions,
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 11.5,
                  color: Colors.grey.shade500)),
        ],
      ],
    ),
  );
}

/// شبكة بطاقات متجاوبة: 3 أعمدة، ثم 2، ثم 1
Widget expoGrid(List<Widget> items, {int maxCols = 3}) {
  return LayoutBuilder(builder: (context, c) {
    const gap = 12.0;
    int cols = maxCols;
    if (c.maxWidth < 620) {
      cols = 1;
    } else if (c.maxWidth < 1000 && cols > 2) {
      cols = 2;
    }
    final w = (c.maxWidth - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: items.map((i) => SizedBox(width: w, child: i)).toList(),
    );
  });
}

/// تبويبات على شكل بطاقات (نفس أسلوب «العروض والتصنيفات»)
class ExpoTabs extends StatelessWidget {
  final List<(String, IconData)> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  const ExpoTabs(
      {super.key,
      required this.tabs,
      required this.index,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: i == index ? kBrand : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: i == index ? kBrand : kLine),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tabs[i].$2,
                      size: 17,
                      color: i == index ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(tabs[i].$1,
                      style: TextStyle(
                        fontFamily: kExpoFont,
                        fontSize: 13,
                        fontWeight:
                            i == index ? FontWeight.bold : FontWeight.normal,
                        color: i == index ? Colors.white : Colors.grey.shade700,
                      )),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== عناصر الواجهة =====================

class ExpoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  const ExpoCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.onTap,
      this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? kLine),
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

/// شارة الحالة
Widget expoChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: kExpoFont,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color)),
    );

/// زر: الأساسي أحمر بأيقونة، والثانوي بإطار خفيف
Widget expoButton(String label, VoidCallback? onTap,
        {bool primary = false, IconData? icon}) =>
    Padding(
      padding: const EdgeInsets.only(left: 8),
      child: primary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon ?? Icons.check_rounded, size: 18),
              label: Text(label,
                  style: const TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon ?? Icons.chevron_left_rounded,
                  size: 17, color: Colors.grey.shade600),
              label: Text(label,
                  style: TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800)),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: kLine),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
    );

/// أيقونة إجراء داخل البطاقة (تعديل رمادي، حذف أحمر)
Widget expoIconAction(IconData icon, VoidCallback onTap,
        {Color? color, String? tooltip}) =>
    Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color ?? Colors.grey.shade600),
        ),
      ),
    );

Widget expoEdit(VoidCallback onTap) =>
    expoIconAction(Icons.edit_outlined, onTap, tooltip: 'تعديل');

Widget expoDelete(VoidCallback onTap) => expoIconAction(
    Icons.delete_outline_rounded, onTap,
    color: Colors.red, tooltip: 'حذف');

/// سطر معلومة صغير بأيقونة
Widget expoStat(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 11.5,
                  color: Colors.grey.shade700)),
        ),
      ],
    );

/// بطاقة رقم (نفس بطاقات الصفحة الرئيسية)
Widget expoStatCard(String label, dynamic value) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 13,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('${value ?? 0}',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: kBrand)),
        ],
      ),
    );

Widget expoTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Text(text,
          style: const TextStyle(
              fontFamily: kExpoFont, fontSize: 15, fontWeight: FontWeight.bold)),
    );

Widget expoSub(String text) => Text(text,
    style: TextStyle(
        fontFamily: kExpoFont, fontSize: 11.5, color: Colors.grey.shade600));

const Divider kExpoDivider = Divider(color: kLine, height: 1);

Widget expoEmpty(String text, {IconData icon = Icons.inbox_outlined}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Icon(icon, size: 58, color: Colors.grey.shade300),
        const SizedBox(height: 14),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: kExpoFont, fontSize: 15, color: Colors.grey)),
      ]),
    );

Widget expoLoader() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator(color: kBrand)),
    );

Widget expoFailed(Object? e) => Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(expoError(e ?? ''),
            style: const TextStyle(fontFamily: kExpoFont, color: Colors.red)),
      ),
    );

/// حقل إدخال بنفس أسلوب اللوحة
InputDecoration expoInput(String label, {String? hint, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
          fontFamily: kExpoFont, fontSize: 13, color: Colors.grey.shade600),
      hintStyle: TextStyle(
          fontFamily: kExpoFont, fontSize: 12, color: Colors.grey.shade400),
      prefixIcon:
          icon == null ? null : Icon(icon, size: 19, color: Colors.grey.shade500),
      filled: true,
      fillColor: kBg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: kBrand, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

const TextStyle kExpoFieldText = TextStyle(fontFamily: kExpoFont, fontSize: 13.5);

/// مفتاح تشغيل صغير مع نص
Widget expoSwitch(String label, bool value, ValueChanged<bool> onChanged) => Row(
      children: [
        Transform.scale(
          scale: 0.78,
          child: Switch(
              value: value,
              activeTrackColor: Colors.green,
              onChanged: onChanged),
        ),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 12.5,
                  color: Colors.grey.shade700)),
        ),
      ],
    );

/// عنوان النافذة المنبثقة: أيقونة في مربع + نص
Widget expoDialogTitle(String title, IconData icon) => Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kBrand.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: kBrand, size: 17),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(title,
            style: const TextStyle(
                fontFamily: kExpoFont,
                fontSize: 15.5,
                fontWeight: FontWeight.bold)),
      ),
    ]);

/// نافذة نموذج منبثقة (إضافة/تعديل). تُفتح بـ showDialog وتُغلق بـ Navigator.pop(context, true)
class ExpoFormPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final bool saving;
  final double maxWidth;
  const ExpoFormPage(
      {super.key,
      required this.title,
      required this.children,
      required this.onSave,
      this.icon = Icons.edit_outlined,
      this.saving = false,
      this.maxWidth = 520});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: expoDialogTitle(title, icon),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minWidth: maxWidth),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(fontFamily: kExpoFont, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrand,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: saving ? null : onSave,
            child: Text(saving ? 'جاري الحفظ...' : 'حفظ',
                style: const TextStyle(
                    fontFamily: kExpoFont,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// نافذة تحميل أثناء جلب بيانات النموذج
class ExpoDialogLoader extends StatelessWidget {
  const ExpoDialogLoader({super.key});
  @override
  Widget build(BuildContext context) => const Dialog(
        backgroundColor: Colors.white,
        child: SizedBox(
            width: 200,
            height: 140,
            child: Center(child: CircularProgressIndicator(color: kBrand))),
      );
}

/// فاصل عنوان داخل النموذج (أيقونة حمراء + نص + ملاحظة)
Widget expoFormSection(String title, IconData icon, {String? note}) => Row(
      children: [
        Icon(icon, size: 17, color: kBrand),
        const SizedBox(width: 9),
        Text(title,
            style: const TextStyle(
                fontFamily: kExpoFont,
                fontSize: 13.5,
                fontWeight: FontWeight.bold)),
        const Spacer(),
        if (note != null)
          Text(note,
              style: TextStyle(
                  fontFamily: kExpoFont,
                  fontSize: 10.5,
                  color: Colors.grey.shade500)),
      ],
    );

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
        if (mounted) expoToast(context, 'الحد الأقصى 5 ميجابايت', warn: true);
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
      if (mounted) expoToast(context, 'تعذر رفع الصورة', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = expoPublicUrl(_path);
    final has = _path != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url != null) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(url,
                  height: 90,
                  width: widget.wide ? null : 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: _busy ? null : _pick,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: has ? Colors.green.withValues(alpha: 0.05) : kBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: has
                      ? Colors.green.withValues(alpha: 0.35)
                      : Colors.grey.shade300),
            ),
            child: Row(children: [
              Icon(has ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  size: 18,
                  color: has ? Colors.green : Colors.grey.shade600),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  _busy
                      ? 'جاري الرفع...'
                      : (has ? 'تغيير ${widget.label}' : 'اختر ${widget.label}'),
                  style: TextStyle(
                    fontFamily: kExpoFont,
                    fontSize: 12.5,
                    color: has ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
              ),
              if (has && !_busy)
                InkWell(
                  onTap: () {
                    setState(() => _path = null);
                    widget.onChanged(null);
                  },
                  child: Icon(Icons.close_rounded,
                      size: 17, color: Colors.grey.shade500),
                ),
            ]),
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
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              v == null
                  ? label
                  : '$label: ${v.day}/${v.month}/${v.year}  ${_two(v.hour)}:${_two(v.minute)}',
              style: TextStyle(
                fontFamily: kExpoFont,
                fontSize: 12.5,
                color: v == null ? Colors.grey.shade500 : kInk,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
