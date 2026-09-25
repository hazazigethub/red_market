import 'package:flutter/material.dart';
import 'package:red_market_core/red_market_core.dart';

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

  Future<void> _setStatus(String status, String question) async {
    if (!await expoConfirm(context, 'حالة المعرض', question)) return;
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb.from('exhibitions').update({'status': status}).eq('id', e['id']),
        ok: 'تم تغيير الحالة');
    if (ok) await widget.onChanged();
  }

  Future<void> _delete() async {
    if (!await expoConfirm(context, 'حذف المعرض',
        'سيُحذف المعرض وكل محتواه نهائياً. يُسمح بالحذف للمسودات فقط.')) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(context,
        () => expoDb.from('exhibitions').delete().eq('id', e['id']),
        ok: 'تم حذف المعرض');
    if (ok && mounted) Navigator.pop(context);
  }

  Widget _stat(String label, dynamic value) => ExpoCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            expoSub(label),
            const SizedBox(height: 6),
            Text('${value ?? 0}',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final status = '${e['status']}';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ===== الحالة =====
        ExpoCard(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['organizers']?['name'] ?? ''}',
                      style: const TextStyle(
                          fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
                  expoSub(
                      '${expoFmtDateTime(e['starts_at'])}  —  ${expoFmtDateTime(e['ends_at'])}'),
                  expoSub(
                      'ينتقل تلقائياً إلى «مباشر» عند البداية، و«انتهى» عند النهاية، ويُؤرشف بعد 7 أيام'),
                ],
              ),
              const SizedBox(width: 16),
              if (status == 'draft')
                expoButton('نشر المعرض',
                    () => _setStatus('scheduled', 'نشر المعرض للزوار والعارضين؟'),
                    primary: true, icon: Icons.publish),
              if (status == 'scheduled')
                expoButton('إلغاء النشر',
                    () => _setStatus('draft', 'إعادة المعرض إلى مسودة؟')),
              if (status == 'scheduled')
                expoButton('ابدأ الآن',
                    () => _setStatus('live', 'بدء المعرض الآن قبل موعده؟'),
                    primary: true, icon: Icons.play_arrow),
              if (status == 'live')
                expoButton('إنهاء المعرض',
                    () => _setStatus('ended', 'إنهاء المعرض الآن؟')),
              expoButton('تعديل البيانات', widget.onEdit),
              if (status == 'draft') expoButton('حذف', _delete),
            ],
          ),
        ),

        // ===== تنبيه الاشتراكات =====
        FutureBuilder<List<Map<String, dynamic>>>(
          future: expoDb
              .rpc('exhibition_subscription_check', params: {'p_exhibition': e['id']})
              .then((v) => List<Map<String, dynamic>>.from(v as List)),
          builder: (context, snap) {
            final bad = (snap.data ?? [])
                .where((x) => x['booth_id'] != null && x['status'] != 'ok')
                .toList();
            if (bad.isEmpty) return const SizedBox.shrink();
            return ExpoCard(
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اشتراك ${bad.map((x) => x['store_name']).join('، ')} لا يغطي فترة المعرض حتى نهايته.',
                    style: const TextStyle(fontFamily: kExpoFont, fontSize: 12.5),
                  ),
                ),
              ]),
            );
          },
        ),

        // ===== الأرقام =====
        FutureBuilder<dynamic>(
          future: expoDb.rpc('organizer_overview', params: {'p_exhibition': e['id']}),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return expoLoader();
            if (snap.hasError) return expoFailed(snap.error);
            final o = Map<String, dynamic>.from(snap.data as Map);
            final stats = [
              ['الزوار', o['visitors']],
              ['الأجنحة المنشورة', '${o['booths_published']}/${o['booths']}'],
              ['طلبات معلقة', o['applications_pending']],
              ['العملاء المحتملون', o['leads']],
              ['المحادثات', o['chats']],
              ['تسجيلات الجلسات', o['registrations']],
              ['بث مباشر الآن', o['live_streams']],
              ['مشاهدون الآن', o['live_viewers']],
            ];
            final top = List<Map<String, dynamic>>.from(
                (o['top_booths'] ?? []) as List);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, c) {
                  const gap = 12.0;
                  final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 620 ? 2 : 1);
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    children: stats
                        .map((s) => SizedBox(width: w, child: _stat('${s[0]}', s[1])))
                        .toList(),
                  );
                }),
                if (top.isNotEmpty) ...[
                  expoTitle('الأجنحة الأكثر زيارة'),
                  ...top.map((b) => ExpoCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Expanded(
                              child: Text('${b['name']}',
                                  style: const TextStyle(fontFamily: kExpoFont))),
                          expoSub(
                              '${b['views_count']} زيارة · ${b['follows_count']} متابع · ${b['leads']} عميل'),
                        ]),
                      )),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
