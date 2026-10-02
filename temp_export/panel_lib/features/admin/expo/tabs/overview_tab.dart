import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../expo_common.dart';

class OverviewTab extends StatefulWidget {
  final Map<String, dynamic> exhibition;
  final Future<void> Function() onChanged;
  final VoidCallback onEdit;
  const OverviewTab(
      {super.key,
      required this.exhibition,
      required this.onChanged,
      required this.onEdit});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, dynamic> get e => widget.exhibition;
  String get _link => '$kExpoSite/e/${e['slug']}';

  Future<void> _setStatus(String status, String title, String question) async {
    if (!await expoConfirm(context, title, question)) return;
    if (!mounted) return;
    final ok = await expoRun(
        context,
        () => expoDb
            .from('exhibitions')
            .update({'status': status}).eq('id', e['id']),
        ok: 'تم تغيير حالة المعرض');
    if (ok) await widget.onChanged();
  }

  Future<void> _delete() async {
    if (!await expoConfirm(context, 'حذف المعرض',
        'سيُحذف «${e['title']}» نهائياً بكل قاعاته وجلساته ومتحدثيه ورعاته.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb.from('exhibitions').delete().eq('id', e['id']),
        ok: 'حُذف المعرض');
    if (ok && mounted) Navigator.pop(context);
  }

  Widget _statusCard() {
    final status = '${e['status']}';
    final (String hint, List<Widget> actions) = switch (status) {
      'draft' => (
          'المعرض مسودة ولا يراه أحد. انشره ليظهر للزوار ويبدأ استقبال طلبات العارضين.',
          [
            expoDelete(_delete),
            expoButton('نشر المعرض',
                () => _setStatus('scheduled', 'نشر المعرض', 'نشر المعرض للزوار والعارضين؟'),
                primary: true, icon: Icons.publish_rounded),
          ]
        ),
      'scheduled' => (
          'منشور. يتحول تلقائياً إلى «مباشر» عند موعد البداية.',
          [
            expoButton('إرجاع لمسودة',
                () => _setStatus('draft', 'إلغاء النشر', 'إخفاء المعرض وإعادته مسودة؟'),
                icon: Icons.undo_rounded),
            expoButton('ابدأ الآن',
                () => _setStatus('live', 'بدء المعرض', 'بدء المعرض الآن قبل موعده؟'),
                primary: true, icon: Icons.play_arrow_rounded),
          ]
        ),
      'live' => (
          'المعرض مباشر الآن. ينتهي تلقائياً عند موعد النهاية.',
          [
            expoButton('إنهاء المعرض',
                () => _setStatus('ended', 'إنهاء المعرض', 'إنهاء المعرض الآن قبل موعده؟'),
                icon: Icons.stop_rounded),
          ]
        ),
      'ended' => ('انتهى المعرض، ومحتواه متاح للتصفح. يُؤرشف تلقائياً بعد 7 أيام.', <Widget>[]),
      _ => ('المعرض مؤرشف.', <Widget>[]),
    };
    return ExpoCard(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (kExhibitionStatusColor[status] ?? Colors.grey)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.flag_outlined,
              size: 20, color: kExhibitionStatusColor[status] ?? Colors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الحالة: ${kExhibitionStatus[status] ?? status}',
                  style: const TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              expoSub(hint),
            ],
          ),
        ),
        ...actions,
      ]),
    );
  }

  Widget _linkCard() => ExpoCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(children: [
          Icon(Icons.link_rounded, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(_link,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: kInk)),
          ),
          expoIconAction(Icons.copy_rounded, () async {
            await Clipboard.setData(ClipboardData(text: _link));
            if (mounted) expoToast(context, 'نُسخ رابط المعرض');
          }, tooltip: 'نسخ الرابط — للبنرات والمشاركة'),
          expoIconAction(Icons.open_in_new_rounded, () => expoOpen('/e/${e['slug']}'),
              tooltip: 'فتح'),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusCard(),
        _linkCard(),

        // ===== تنبيه الاشتراكات =====
        FutureBuilder<dynamic>(
          future: expoDb.rpc('exhibition_subscription_check',
              params: {'p_exhibition': e['id']}),
          builder: (context, snap) {
            final rows = snap.data is List
                ? List<Map<String, dynamic>>.from(snap.data as List)
                : <Map<String, dynamic>>[];
            final bad = rows
                .where((x) => x['booth_id'] != null && x['status'] != 'ok')
                .toList();
            if (bad.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'اشتراك ${bad.map((x) => x['store_name']).join('، ')} لا يغطي فترة المعرض حتى نهايته.',
                    style: const TextStyle(
                        fontFamily: kExpoFont, fontSize: 12, height: 1.9),
                  ),
                ),
              ]),
            );
          },
        ),

        const SizedBox(height: 8),

        // ===== الأرقام =====
        FutureBuilder<dynamic>(
          future:
              expoDb.rpc('organizer_overview', params: {'p_exhibition': e['id']}),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return expoLoader();
            if (snap.hasError) return expoFailed(snap.error);
            final o = Map<String, dynamic>.from(snap.data as Map);
            final top =
                List<Map<String, dynamic>>.from((o['top_booths'] ?? []) as List);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                expoGrid([
                  expoStatCard('الزوار', o['visitors']),
                  expoStatCard(
                      e['max_booths'] == null ? 'الأجنحة (بلا حد)' : 'الأجنحة المشغولة',
                      e['max_booths'] == null
                          ? '${o['booths']}'
                          : expoOf(o['booths'], e['max_booths'])),
                  expoStatCard('الأجنحة المنشورة', o['booths_published']),
                  expoStatCard('طلبات بانتظار المراجعة', o['applications_pending']),
                  expoStatCard('العملاء المحتملون', o['leads']),
                  expoStatCard('المحادثات', o['chats']),
                  expoStatCard('تسجيلات الجلسات', o['registrations']),
                  expoStatCard('بث مباشر الآن', o['live_streams']),
                  expoStatCard('مشاهدون الآن', o['live_viewers']),
                ], maxCols: 4),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  expoTitle('الأجنحة الأكثر زيارة'),
                  ExpoCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < top.length; i++) ...[
                          if (i > 0)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: kExpoDivider),
                          Row(children: [
                            Text('${i + 1}',
                                style: const TextStyle(
                                    fontFamily: kExpoFont,
                                    fontWeight: FontWeight.bold,
                                    color: kBrand)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text('${top[i]['name']}',
                                    style: const TextStyle(
                                        fontFamily: kExpoFont,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600))),
                            expoStat(Icons.visibility_outlined,
                                '${top[i]['views_count']}'),
                            const SizedBox(width: 16),
                            expoStat(Icons.favorite_border_rounded,
                                '${top[i]['follows_count']}'),
                            const SizedBox(width: 16),
                            expoStat(Icons.person_add_alt_outlined,
                                '${top[i]['leads']}'),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
