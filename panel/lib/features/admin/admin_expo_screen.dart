import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:red_market_core/red_market_core.dart';

import 'expo/expo_exhibition_form.dart';
import 'expo/expo_manage_screen.dart';

/// إدارة المعارض (Expo Red Market) من لوحة الأدمن.
/// تقرأ وتكتب في مخطط expo بنفس جلسة الأدمن.
/// الصلاحيات تُفحص في قاعدة البيانات نفسها، لا في هذه الشاشة.
class AdminExpoScreen extends StatefulWidget {
  const AdminExpoScreen({super.key});

  @override
  State<AdminExpoScreen> createState() => _AdminExpoScreenState();
}

class _AdminExpoScreenState extends State<AdminExpoScreen> {
  static const String _expoUrl = 'https://expo.redmarket.pro';
  static const String _font = 'Cairo';

  late final _db = Supabase.instance.client.schema('expo');

  static const Map<String, String> _statusLabels = {
    'draft': 'مسودة',
    'scheduled': 'مجدول',
    'live': 'مباشر',
    'ended': 'انتهى',
    'archived': 'مؤرشف',
  };

  static const Map<String, Color> _statusColors = {
    'draft': Colors.grey,
    'scheduled': Colors.blue,
    'live': Colors.red,
    'ended': Colors.black54,
    'archived': Colors.brown,
  };

  // ===================== أدوات عامة =====================

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: _font)),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  String _errorText(String message) {
    if (message.contains('booths_store_id_fkey')) {
      return 'لا يمكن حذف عارض لديه أجنحة. احذف أجنحته من صفحة المعرض أولاً، أو أوقفه بدل الحذف.';
    }
    if (message.contains('exhibitions_organizer_id_fkey')) {
      return 'لا يمكن حذف جهة لديها معارض. احذف معارضها أولاً، أو أوقفها بدل الحذف.';
    }
    if (message.contains('INVALID_STATUS_TRANSITION')) {
      return 'لا يمكن الانتقال إلى هذه الحالة';
    }
    if (message.contains('permission') || message.contains('row-level')) {
      return 'ليست لديك صلاحية لهذا الإجراء';
    }
    return 'تعذر الحفظ: $message';
  }

  /// تحديث صف واحد، مع التأكد أن التحديث تم فعلاً (الصلاحيات قد ترفضه بصمت)
  Future<void> _update(String table, String id, Map<String, dynamic> values,
      String okMessage) async {
    try {
      final rows =
          await _db.from(table).update(values).eq('id', id).select('id');
      if ((rows as List).isEmpty) {
        _toast('ليست لديك صلاحية لهذا الإجراء', error: true);
        return;
      }
      _toast(okMessage);
      if (mounted) setState(() {});
    } on PostgrestException catch (e) {
      _toast(_errorText(e.message), error: true);
    } catch (_) {
      _toast('فشل الاتصال بالخادم', error: true);
    }
  }

  Future<void> _delete(String table, String id, String name, String okMessage) async {
    if (!await _confirm('حذف نهائي', 'حذف «$name» نهائياً؟ لا يمكن التراجع.')) return;
    try {
      final rows = await _db.from(table).delete().eq('id', id).select('id');
      if ((rows as List).isEmpty) {
        _toast('ليست لديك صلاحية لهذا الإجراء', error: true);
        return;
      }
      _toast(okMessage);
      if (mounted) setState(() {});
    } on PostgrestException catch (e) {
      _toast(_errorText('${e.message} ${e.details ?? ''}'), error: true);
    } catch (_) {
      _toast('فشل الاتصال بالخادم', error: true);
    }
  }

  Future<void> _open(String path) async {
    await launchUrl(Uri.parse('$_expoUrl$path'), webOnlyWindowName: '_blank');
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    return d == null ? '—' : '${d.day}/${d.month}/${d.year}';
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title,
              style: const TextStyle(
                  fontFamily: _font, fontWeight: FontWeight.bold)),
          content: Text(body, style: const TextStyle(fontFamily: _font)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: _font))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد', style: TextStyle(fontFamily: _font)),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إيقاف العارض من المعارض',
              style: TextStyle(fontFamily: _font, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'تختفي أجنحته عن الزوار، ولا يستطيع التقديم على معارض جديدة. متجره في Red Market لا يتأثر.',
                  style: TextStyle(fontFamily: _font, fontSize: 12.5)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 200,
                decoration: const InputDecoration(
                    labelText: 'سبب الإيقاف', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: _font))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إيقاف', style: TextStyle(fontFamily: _font)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return reason;
  }

  Future<void> _newOrganizer() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('جهة منظمة جديدة',
              style: TextStyle(fontFamily: _font, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'اسم الجهة', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(fontFamily: _font))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('إنشاء', style: TextStyle(fontFamily: _font)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (name == null || name.length < 2) return;
    try {
      final row = await _db
          .from('organizers')
          .insert({'name': name})
          .select('id')
          .single();
      // الأدمن ينشئ الجهة موثّقة مباشرة
      await _db
          .from('organizers')
          .update({'is_verified': true}).eq('id', row['id']);
      _toast('تم إنشاء الجهة المنظمة وتوثيقها');
      if (mounted) setState(() {});
    } on PostgrestException catch (e) {
      _toast(_errorText(e.message), error: true);
    } catch (_) {
      _toast('فشل الاتصال بالخادم', error: true);
    }
  }

  Future<void> _newExhibition() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ExpoExhibitionFormPage()),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _manage(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpoManageScreen(exhibitionId: id)),
    );
    if (mounted) setState(() {});
  }

  // ===================== عناصر الواجهة =====================

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEFF3)),
        ),
        child: child,
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: _font,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color)),
      );

  Widget _action(String label, VoidCallback onTap, {bool primary = false}) =>
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: primary
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0),
                child: Text(label,
                    style: const TextStyle(fontFamily: _font, fontSize: 12)),
              )
            : OutlinedButton(
                onPressed: onTap,
                child: Text(label,
                    style: const TextStyle(fontFamily: _font, fontSize: 12)),
              ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
            child: Text(text,
                style: const TextStyle(fontFamily: _font, color: Colors.grey))),
      );

  Widget _loader() =>
      Center(child: CircularProgressIndicator(color: AppColors.brand));

  Widget _failed(Object? e) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('تعذر تحميل البيانات: $e',
            style: const TextStyle(fontFamily: _font, color: Colors.red)),
      );

  // ===================== التبويب 1: الإحصاءات =====================

  Widget _statsTab() {
    return FutureBuilder<dynamic>(
      future: _db.rpc('admin_overview'),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loader();
        if (snap.hasError) return _failed(snap.error);
        final o = Map<String, dynamic>.from(snap.data as Map);
        final byStatus =
            Map<String, dynamic>.from((o['exhibitions_by_status'] ?? {}) as Map);
        final items = <List<String>>[
          ['معارض مباشرة', '${byStatus['live'] ?? 0}'],
          ['معارض مجدولة', '${byStatus['scheduled'] ?? 0}'],
          ['بث مباشر الآن', '${o['live_streams'] ?? 0}'],
          ['مشاهدون الآن', '${o['live_viewers'] ?? 0}'],
          ['زوار آخر 30 يوماً', '${o['visitors_30d'] ?? 0}'],
          ['العملاء المحتملون', '${o['leads'] ?? 0}'],
          ['الأجنحة', '${o['booths'] ?? 0}'],
          ['المنظمون', '${o['organizers'] ?? 0}'],
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(builder: (context, c) {
            const gap = 14.0;
            final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 620 ? 2 : 1);
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: items
                  .map((s) => SizedBox(
                        width: w,
                        child: _card(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s[0],
                                  style: TextStyle(
                                      fontFamily: _font,
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text(s[1],
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brand)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          }),
        );
      },
    );
  }

  // ===================== التبويب 2: المنظمون =====================

  Widget _organizersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db
          .from('organizers')
          .select('id, name, is_verified, is_suspended, created_at')
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loader();
        if (snap.hasError) return _failed(snap.error);
        final list = snap.data ?? [];
        if (list.isEmpty) return _empty('لا يوجد منظمون بعد');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: list.map((g) {
            final verified = g['is_verified'] == true;
            final suspended = g['is_suspended'] == true;
            return _card(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g['name']}',
                            style: const TextStyle(
                                fontFamily: _font,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('أُنشئ ${_date(g['created_at'])}',
                            style: TextStyle(
                                fontFamily: _font,
                                fontSize: 11.5,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  suspended
                      ? _chip('موقوف', Colors.black87)
                      : verified
                          ? _chip('موثّق', Colors.green)
                          : _chip('بانتظار التوثيق', Colors.orange),
                  const SizedBox(width: 12),
                  _action(
                    verified ? 'إلغاء التوثيق' : 'توثيق',
                    () => _update('organizers', g['id'],
                        {'is_verified': !verified},
                        verified ? 'تم إلغاء التوثيق' : 'تم توثيق المنظم'),
                    primary: !verified,
                  ),
                  _action(
                    suspended ? 'رفع الإيقاف' : 'إيقاف',
                    () async {
                      if (!suspended &&
                          !await _confirm('إيقاف المنظم',
                              'لن يستطيع نشر معارض جديدة. هل تريد المتابعة؟')) {
                        return;
                      }
                      await _update('organizers', g['id'],
                          {'is_suspended': !suspended},
                          suspended ? 'تم رفع الإيقاف' : 'تم إيقاف المنظم');
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _delete('organizers', '${g['id']}',
                        '${g['name']}', 'تم حذف الجهة المنظمة'),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ===================== التبويب 3: العارضون =====================

  Widget _exhibitorsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db
          .from('store')
          .select(
              'id, name, logo_url, status, suspended_reason, created_at, booths(count)')
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loader();
        if (snap.hasError) return _failed(snap.error);
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _empty('لم يسجل أي عارض بعد. يُسجَّل التاجر تلقائياً عند أول طلب مشاركة.');
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: list.map((s) {
            final active = s['status'] == 'active';
            final booths = (s['booths'] is List && (s['booths'] as List).isNotEmpty)
                ? '${(s['booths'] as List).first['count']}'
                : '0';
            final logo = s['logo_url'] as String?;
            return _card(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.08),
                    backgroundImage: logo != null ? NetworkImage(logo) : null,
                    child: logo == null
                        ? Icon(Icons.store, color: AppColors.brand, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['name']}',
                            style: const TextStyle(
                                fontFamily: _font,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'الأجنحة: $booths · سُجّل ${_date(s['created_at'])}'
                          '${!active && s['suspended_reason'] != null ? ' · السبب: ${s['suspended_reason']}' : ''}',
                          style: TextStyle(
                              fontFamily: _font,
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  active
                      ? _chip('نشط', Colors.green)
                      : _chip('موقوف', Colors.black87),
                  const SizedBox(width: 12),
                  active
                      ? _action('إيقاف', () async {
                          final reason = await _askReason();
                          if (reason == null) return;
                          await _update(
                              'store',
                              s['id'],
                              {
                                'status': 'suspended',
                                'suspended_reason':
                                    reason.isEmpty ? null : reason,
                              },
                              'تم إيقاف العارض من المعارض');
                        })
                      : _action(
                          'إعادة التفعيل',
                          () => _update(
                              'store',
                              s['id'],
                              {'status': 'active', 'suspended_reason': null},
                              'تمت إعادة تفعيل العارض'),
                          primary: true,
                        ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _delete('store', '${s['id']}', '${s['name']}',
                        'تم حذف العارض من المعارض'),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ===================== التبويب 4: المعارض =====================

  Widget _exhibitionsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db
          .from('exhibitions')
          .select(
              'id, title, slug, status, starts_at, ends_at, is_featured, organizers(name)')
          .order('starts_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loader();
        if (snap.hasError) return _failed(snap.error);
        final list = snap.data ?? [];
        if (list.isEmpty) return _empty('لا توجد معارض بعد');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: list.map((e) {
            final status = '${e['status']}';
            final featured = e['is_featured'] == true;
            final org = e['organizers'] is Map ? e['organizers']['name'] : null;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _manage('${e['id']}'),
              child: _card(
              child: Row(
                children: [
                  IconButton(
                    tooltip: featured ? 'إلغاء التمييز' : 'تمييز في الصفحة الرئيسية',
                    icon: Icon(featured ? Icons.star : Icons.star_border,
                        color: featured ? Colors.amber : Colors.grey),
                    onPressed: () => _update('exhibitions', e['id'],
                        {'is_featured': !featured},
                        featured ? 'تم إلغاء التمييز' : 'تم تمييز المعرض'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e['title']}',
                            style: const TextStyle(
                                fontFamily: _font,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '${org ?? '—'} · ${_date(e['starts_at'])} — ${_date(e['ends_at'])}',
                          style: TextStyle(
                              fontFamily: _font,
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _chip(_statusLabels[status] ?? status,
                      _statusColors[status] ?? Colors.grey),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'تغيير الحالة',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'open') return _open('/e/${e['slug']}');
                      if (v == 'manage') return _manage('${e['id']}');
                      if (!await _confirm('تغيير حالة المعرض',
                          'تغيير الحالة إلى «${_statusLabels[v]}»؟')) {
                        return;
                      }
                      await _update('exhibitions', e['id'], {'status': v},
                          'تم تغيير الحالة');
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'open',
                          child: Text('عرض المعرض كزائر',
                              style: TextStyle(fontFamily: _font))),
                      const PopupMenuItem(
                          value: 'manage',
                          child: Text('إدارة المعرض',
                              style: TextStyle(fontFamily: _font))),
                      const PopupMenuDivider(),
                      ..._statusLabels.entries
                          .where((s) => s.key != status)
                          .map((s) => PopupMenuItem(
                                value: s.key,
                                child: Text('تغيير إلى: ${s.value}',
                                    style: const TextStyle(fontFamily: _font)),
                              )),
                    ],
                  ),
                ],
              ),
            ),
            );
          }).toList(),
        );
      },
    );
  }

  // ===================== البناء =====================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 4,
        child: Container(
          color: const Color(0xFFF7F8FA),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Row(
                  children: [
                    Text('المعارض',
                        style: TextStyle(
                            fontFamily: _font,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'تحديث',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() {}),
                    ),
                    _action('منظم جديد', _newOrganizer),
                    _action('معرض جديد', _newExhibition, primary: true),
                    _action('فتح موقع المعارض', () => _open('/')),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                labelColor: AppColors.brand,
                indicatorColor: AppColors.brand,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                    fontFamily: _font, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontFamily: _font),
                tabs: const [
                  Tab(text: 'الإحصاءات'),
                  Tab(text: 'المنظمون'),
                  Tab(text: 'العارضون'),
                  Tab(text: 'المعارض'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _statsTab(),
                    _organizersTab(),
                    _exhibitorsTab(),
                    _exhibitionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
