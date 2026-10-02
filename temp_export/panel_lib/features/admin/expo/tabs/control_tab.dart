import 'package:flutter/material.dart';

import '../expo_common.dart';

class ControlTab extends StatefulWidget {
  final Map<String, dynamic> exhibition;
  const ControlTab({super.key, required this.exhibition});

  @override
  State<ControlTab> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  final _message = TextEditingController();
  bool _sending = false;
  late Future<Map<String, List<Map<String, dynamic>>>> _future;

  String get _id => '${widget.exhibition['id']}';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final streams = await expoDb
        .from('live_streams')
        .select(
            'id, title, status, current_viewers, peak_viewers, booth_id, session_id, booths(name)')
        .eq('exhibition_id', _id)
        .inFilter('status', ['live', 'scheduled'])
        .order('status');
    final bans = await expoDb
        .from('exhibition_bans')
        .select('user_id, reason, expires_at, created_at')
        .eq('exhibition_id', _id)
        .order('created_at', ascending: false);
    return {'streams': streams, 'bans': bans};
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _announce() async {
    final text = _message.text.trim();
    if (text.length < 2) {
      return expoToast(context, 'اكتب نص الإعلان', warn: true);
    }
    if (!await expoConfirm(context, 'إرسال إعلان',
        'سيظهر هذا الإعلان فوراً لكل الزوار المتصلين بالمعرض:\n«$text»',
        confirmLabel: 'إرسال')) {
      return;
    }
    if (!mounted) return;
    setState(() => _sending = true);
    final ok = await expoRun(
        context,
        () => expoDb.rpc('announce', params: {'p_exhibition': _id, 'p_message': text}),
        ok: 'أُرسل الإعلان لكل الزوار المتصلين');
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _message.clear();
  }

  Future<void> _unban(String userId) async {
    final ok = await expoRun(
        context,
        () => expoDb
            .from('exhibition_bans')
            .delete()
            .eq('exhibition_id', _id)
            .eq('user_id', userId),
        ok: 'رُفع الحظر');
    if (ok && mounted) _reload();
  }

  Widget _announceCard(bool active) => ExpoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            expoFormSection('إعلان فوري لكل الزوار', Icons.campaign_outlined,
                note: active ? 'يظهر كتنبيه أسفل الشاشة' : 'متاح عند النشر'),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  enabled: active,
                  maxLength: 280,
                  style: kExpoFieldText,
                  decoration: expoInput('نص الإعلان',
                      hint: 'تبدأ الكلمة الرئيسية بعد 5 دقائق في القاعة A',
                      icon: Icons.notes_rounded),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: expoButton(_sending ? 'جاري الإرسال...' : 'إرسال',
                    active && !_sending ? _announce : null,
                    primary: true, icon: Icons.send_rounded),
              ),
            ]),
          ],
        ),
      );

  Widget _streamCard(Map<String, dynamic> s) {
    final live = s['status'] == 'live';
    return ExpoCard(
      borderColor: live ? Colors.green.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text('${s['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: kExpoFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold)),
            ),
            expoChip(live ? 'مباشر' : 'مجدول', live ? Colors.green : Colors.blue),
          ]),
          const SizedBox(height: 6),
          expoStat(s['booth_id'] != null ? Icons.storefront_outlined : Icons.mic_none_rounded,
              s['booth_id'] != null ? 'جناح ${s['booths']?['name'] ?? ''}' : 'جلسة'),
          const SizedBox(height: 12),
          kExpoDivider,
          const SizedBox(height: 10),
          Row(children: [
            expoStat(Icons.visibility_outlined, '${s['current_viewers'] ?? 0} الآن'),
            const SizedBox(width: 16),
            expoStat(Icons.trending_up_rounded, 'ذروة ${s['peak_viewers'] ?? 0}'),
            const Spacer(),
            expoIconAction(Icons.play_circle_outline_rounded,
                () => expoOpen('/e/${widget.exhibition['slug']}/live/${s['id']}'),
                tooltip: 'مشاهدة'),
            expoIconAction(Icons.shield_outlined,
                () => expoOpen('/organizer/e/$_id/control'),
                tooltip: 'إشراف الدردشة'),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = '${widget.exhibition['status']}';
    final active = status == 'scheduled' || status == 'live';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _announceCard(active),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return expoLoader();
            if (snap.hasError) return expoFailed(snap.error);
            final streams = snap.data!['streams']!;
            final bans = snap.data!['bans']!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                expoHeader('البث', count: streams.length,
                    subtitle: 'البث المباشر والمجدول في المعرض', actions: [
                  expoIconAction(Icons.refresh_rounded, _reload, tooltip: 'تحديث'),
                ]),
                if (streams.isEmpty)
                  expoEmpty('لا بث مباشر أو مجدول', icon: Icons.podcasts_rounded)
                else
                  expoGrid(streams.map(_streamCard).toList()),
                const SizedBox(height: 18),
                expoHeader('المحظورون',
                    count: bans.length,
                    subtitle: 'الحظر يتم من الدردشة أثناء الإشراف، وهنا تُرفع القيود'),
                if (bans.isEmpty)
                  expoEmpty('لا يوجد محظورون', icon: Icons.verified_user_outlined)
                else
                  ExpoCard(
                    child: Column(children: [
                      for (var i = 0; i < bans.length; i++) ...[
                        if (i > 0)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: kExpoDivider),
                        Row(children: [
                          const Icon(Icons.block_rounded, size: 16, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${bans[i]['user_id']}'.substring(0, 8),
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontSize: 12.5)),
                                if (bans[i]['reason'] != null)
                                  expoSub('${bans[i]['reason']}'),
                              ],
                            ),
                          ),
                          expoSub(bans[i]['expires_at'] == null
                              ? 'دائم'
                              : 'حتى ${expoFmtDateTime(bans[i]['expires_at'])}'),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _unban('${bans[i]['user_id']}'),
                            child: const Text('رفع الحظر',
                                style: TextStyle(
                                    fontFamily: kExpoFont,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kBrand)),
                          ),
                        ]),
                      ],
                    ]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
