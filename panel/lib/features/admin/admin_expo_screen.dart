import 'package:flutter/material.dart';

import 'expo/expo_common.dart';
import 'expo/expo_exhibition_form.dart';
import 'expo/expo_manage_screen.dart';

/// قسم المعارض في لوحة الأدمن — التحكم الكامل بمنصة Expo Red Market.
/// الصلاحيات تُفحص في قاعدة البيانات نفسها (expo.is_admin).
class AdminExpoScreen extends StatefulWidget {
  const AdminExpoScreen({super.key});

  @override
  State<AdminExpoScreen> createState() => _AdminExpoScreenState();
}

class _AdminExpoScreenState extends State<AdminExpoScreen> {
  int _tab = 0;

  static const _tabs = <(String, IconData)>[
    ('المعارض', Icons.event_available_outlined),
    ('المنظمون', Icons.apartment_outlined),
    ('العارضون', Icons.storefront_outlined),
    ('الإحصاءات', Icons.insights_outlined),
  ];

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ===================== الإجراءات =====================

  Future<void> _newExhibition() async {
    final saved = await showDialog<bool>(
        context: context, builder: (_) => const ExpoExhibitionFormPage());
    if (saved == true) _refresh();
  }

  Future<void> _manage(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpoManageScreen(exhibitionId: id)),
    );
    _refresh();
  }

  Future<void> _newOrganizer() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: expoDialogTitle('جهة منظمة جديدة', Icons.apartment_outlined),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: kExpoFieldText,
              decoration: expoInput('اسم الجهة', icon: Icons.title_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: kExpoFont, color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إنشاء',
                  style: TextStyle(
                      fontFamily: kExpoFont,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    if (name.length < 2) {
      if (mounted) expoToast(context, 'اكتب اسم الجهة', warn: true);
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context, () async {
      final row = await expoDb
          .from('organizers')
          .insert({'name': name})
          .select('id')
          .single();
      // الأدمن ينشئ الجهة موثّقة مباشرة
      await expoDb
          .from('organizers')
          .update({'is_verified': true}).eq('id', row['id']);
    }, ok: 'أُنشئت الجهة المنظمة وتم توثيقها');
    if (ok) _refresh();
  }

  /// تحديث صف مع التأكد أن الصلاحيات لم ترفضه بصمت
  Future<void> _update(String table, String id, Map<String, dynamic> values,
      String okMessage) async {
    final ok = await expoRun(context, () async {
      final rows =
          await expoDb.from(table).update(values).eq('id', id).select('id');
      if ((rows as List).isEmpty) throw 'permission denied';
    }, ok: okMessage);
    if (ok) _refresh();
  }

  Future<void> _delete(String table, String id, String name, String okMessage) async {
    if (!await expoConfirm(
        context, 'حذف نهائي', 'سيُحذف «$name» نهائياً ولا يمكن التراجع.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context, () async {
      final rows = await expoDb.from(table).delete().eq('id', id).select('id');
      if ((rows as List).isEmpty) throw 'permission denied';
    }, ok: okMessage);
    if (ok) _refresh();
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: expoDialogTitle('إيقاف العارض من المعارض', Icons.block_rounded),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                      'تختفي أجنحته عن الزوار، ولا يستطيع التقديم على معارض جديدة. متجره في Red Market لا يتأثر.',
                      style: TextStyle(
                          fontFamily: kExpoFont, fontSize: 12, height: 1.9)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  maxLength: 200,
                  style: kExpoFieldText,
                  decoration:
                      expoInput('سبب الإيقاف', icon: Icons.notes_rounded),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع',
                  style: TextStyle(fontFamily: kExpoFont, color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إيقاف',
                  style: TextStyle(
                      fontFamily: kExpoFont,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return reason;
  }

  // ===================== تبويب المعارض =====================

  Widget _exhibitionsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: expoDb
          .from('exhibitions')
          .select(
              'id, title, slug, status, starts_at, ends_at, is_featured, logo_path, max_booths, organizers(name), booths(count)')
          .order('starts_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return expoEmpty('لا معارض بعد', icon: Icons.event_available_outlined);
        }
        return expoGrid(list.map(_exhibitionCard).toList());
      },
    );
  }

  Widget _exhibitionCard(Map<String, dynamic> e) {
    final status = '${e['status']}';
    final color = kExhibitionStatusColor[status] ?? Colors.grey;
    final featured = e['is_featured'] == true;
    final org = e['organizers'] is Map ? e['organizers']['name'] : null;
    final booths = (e['booths'] is List && (e['booths'] as List).isNotEmpty)
        ? (e['booths'] as List).first['count']
        : 0;
    final logo = expoPublicUrl(e['logo_path'] as String?);

    return ExpoCard(
      onTap: () => _manage('${e['id']}'),
      borderColor: status == 'live' ? Colors.green.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 42,
                height: 42,
                color: kBrand.withValues(alpha: 0.08),
                child: logo == null
                    ? const Icon(Icons.event_available_outlined,
                        color: kBrand, size: 20)
                    : Image.network(logo, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['title']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: kExpoFont,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '${expoFmtDate(e['starts_at'])} — ${expoFmtDate(e['ends_at'])}',
                      style: TextStyle(
                          fontFamily: kExpoFont,
                          fontSize: 11.5,
                          color: Colors.grey.shade600)),
                ],
              ),
            ),
            expoChip(kExhibitionStatus[status] ?? status, color),
          ]),
          const SizedBox(height: 14),
          kExpoDivider,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: expoStat(Icons.apartment_outlined, '${org ?? '—'}', expand: true)),
            const SizedBox(width: 12),
            expoStat(Icons.storefront_outlined,
                e['max_booths'] == null ? '$booths جناح' : '${expoOf(booths, e['max_booths'])} جناح'),
            const SizedBox(width: 4),
            expoIconAction(
              featured ? Icons.star_rounded : Icons.star_border_rounded,
              () => _update('exhibitions', '${e['id']}', {'is_featured': !featured},
                  featured ? 'أُلغي التمييز' : 'تم تمييز المعرض في الصفحة الرئيسية'),
              color: featured ? Colors.amber.shade700 : Colors.grey.shade500,
              tooltip: featured ? 'إلغاء التمييز' : 'تمييز في الصفحة الرئيسية',
            ),
            expoIconAction(Icons.open_in_new_rounded,
                () => expoOpen('/e/${e['slug']}'),
                tooltip: 'عرض كزائر'),
          ]),
        ],
      ),
    );
  }

  // ===================== تبويب المنظمين =====================

  Widget _organizersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: expoDb
          .from('organizers')
          .select('id, name, is_verified, is_suspended, created_at, exhibitions(count)')
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return expoEmpty('لا جهات منظمة بعد', icon: Icons.apartment_outlined);
        }
        return expoGrid(list.map((g) {
          final verified = g['is_verified'] == true;
          final suspended = g['is_suspended'] == true;
          final count = (g['exhibitions'] is List &&
                  (g['exhibitions'] as List).isNotEmpty)
              ? (g['exhibitions'] as List).first['count']
              : 0;
          return ExpoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('${g['name']}',
                        style: const TextStyle(
                            fontFamily: kExpoFont,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                  suspended
                      ? expoChip('موقوفة', Colors.black87)
                      : verified
                          ? expoChip('موثّقة', Colors.green)
                          : expoChip('بانتظار التوثيق', Colors.orange),
                  const SizedBox(width: 6),
                  expoDelete(() => _delete('organizers', '${g['id']}',
                      '${g['name']}', 'حُذفت الجهة المنظمة')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  expoStat(Icons.event_available_outlined, '$count معرض'),
                  const SizedBox(width: 18),
                  expoStat(Icons.schedule_rounded,
                      'أُنشئت ${expoFmtDate(g['created_at'])}'),
                ]),
                const SizedBox(height: 12),
                kExpoDivider,
                const SizedBox(height: 6),
                expoSwitch(
                  verified ? 'موثّقة — تستطيع نشر المعارض' : 'غير موثّقة',
                  verified,
                  (v) => _update('organizers', '${g['id']}', {'is_verified': v},
                      v ? 'تم التوثيق' : 'أُلغي التوثيق'),
                ),
                expoSwitch(
                  suspended ? 'موقوفة' : 'غير موقوفة',
                  suspended,
                  (v) => _update('organizers', '${g['id']}', {'is_suspended': v},
                      v ? 'تم إيقاف الجهة' : 'رُفع الإيقاف'),
                ),
              ],
            ),
          );
        }).toList());
      },
    );
  }

  // ===================== تبويب العارضين =====================

  Widget _exhibitorsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: expoDb
          .from('store')
          .select(
              'id, name, logo_url, status, suspended_reason, created_at, booths(count)')
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return expoEmpty(
              'لم يسجل أي عارض بعد\nيُسجَّل التاجر تلقائياً عند أول طلب مشاركة',
              icon: Icons.storefront_outlined);
        }
        return expoGrid(list.map((s) {
          final active = s['status'] == 'active';
          final booths =
              (s['booths'] is List && (s['booths'] as List).isNotEmpty)
                  ? (s['booths'] as List).first['count']
                  : 0;
          final logo = s['logo_url'] as String?;
          return ExpoCard(
            borderColor: active ? null : Colors.red.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: kBrand.withValues(alpha: 0.08),
                    backgroundImage: logo != null ? NetworkImage(logo) : null,
                    child: logo == null
                        ? const Icon(Icons.storefront_outlined,
                            color: kBrand, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${s['name']}',
                        style: const TextStyle(
                            fontFamily: kExpoFont,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                  expoChip(active ? 'نشط' : 'موقوف',
                      active ? Colors.green : Colors.red),
                  const SizedBox(width: 6),
                  expoDelete(() => _delete('store', '${s['id']}', '${s['name']}',
                      'حُذف العارض من المعارض')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  expoStat(Icons.grid_view_rounded, '$booths جناح'),
                  const SizedBox(width: 18),
                  expoStat(Icons.schedule_rounded,
                      'سُجّل ${expoFmtDate(s['created_at'])}'),
                ]),
                if (!active && s['suspended_reason'] != null) ...[
                  const SizedBox(height: 6),
                  expoStat(Icons.info_outline_rounded, '${s['suspended_reason']}'),
                ],
                const SizedBox(height: 12),
                kExpoDivider,
                const SizedBox(height: 6),
                expoSwitch(
                  active ? 'مسموح له بالمشاركة' : 'موقوف من المعارض',
                  active,
                  (v) async {
                    if (v) {
                      await _update('store', '${s['id']}',
                          {'status': 'active', 'suspended_reason': null},
                          'أُعيد تفعيل العارض');
                      return;
                    }
                    final reason = await _askReason();
                    if (reason == null) return;
                    await _update(
                        'store',
                        '${s['id']}',
                        {
                          'status': 'suspended',
                          'suspended_reason': reason.isEmpty ? null : reason,
                        },
                        'أُوقف العارض من المعارض');
                  },
                ),
              ],
            ),
          );
        }).toList());
      },
    );
  }

  // ===================== تبويب الإحصاءات =====================

  Widget _statsTab() {
    return FutureBuilder<dynamic>(
      future: expoDb.rpc('admin_overview'),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final o = Map<String, dynamic>.from(snap.data as Map);
        final byStatus =
            Map<String, dynamic>.from((o['exhibitions_by_status'] ?? {}) as Map);
        return expoGrid([
          expoStatCard('معارض مباشرة', byStatus['live']),
          expoStatCard('معارض مجدولة', byStatus['scheduled']),
          expoStatCard('بث مباشر الآن', o['live_streams']),
          expoStatCard('مشاهدون الآن', o['live_viewers']),
          expoStatCard('زوار آخر 30 يوماً', o['visitors_30d']),
          expoStatCard('العملاء المحتملون', o['leads']),
          expoStatCard('الأجنحة', o['booths']),
          expoStatCard('الجهات المنظمة', o['organizers']),
        ]);
      },
    );
  }

  // ===================== البناء =====================

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => _exhibitionsTab(),
      1 => _organizersTab(),
      2 => _exhibitorsTab(),
      _ => _statsTab(),
    };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: kBg,
        child: ExpoPage(
          onRefresh: () async => _refresh(),
          children: [
            expoHeader(
              'المعارض',
              subtitle:
                  'أنشئ المعارض وأدرها بالكامل من هنا — موقع المعارض للعرض والزيارات، والتاجر يبني جناحه منه',
              actions: [
                expoIconAction(Icons.open_in_new_rounded, () => expoOpen('/'),
                    tooltip: 'فتح موقع المعارض'),
                expoButton('جهة منظمة', _newOrganizer,
                    icon: Icons.add_rounded),
                expoButton('معرض جديد', _newExhibition,
                    primary: true, icon: Icons.add_rounded),
              ],
            ),
            ExpoTabs(
                tabs: _tabs,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 18),
            body,
          ],
        ),
      ),
    );
  }
}
