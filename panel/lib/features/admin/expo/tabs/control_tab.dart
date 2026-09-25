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

  String get _id => '${widget.exhibition['id']}';

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final streams = await expoDb
        .from('live_streams')
        .select('id, title, status, current_viewers, peak_viewers, booth_id, session_id, booths(name)')
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

  Future<void> _announce() async {
    final text = _message.text.trim();
    if (text.length < 2) return;
    setState(() => _sending = true);
    final ok = await expoRun(
        context,
        () => expoDb
            .rpc('announce', params: {'p_exhibition': _id, 'p_message': text}),
        ok: 'تم إرسال الإعلان لكل الزوار المتصلين');
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
        ok: 'تم رفع الحظر');
    if (ok && mounted) setState(() {});
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = '${widget.exhibition['status']}';
    final active = status == 'scheduled' || status == 'live';
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final streams = snap.data!['streams']!;
        final bans = snap.data!['bans']!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ===== الإعلان =====
            expoTitle('إعلان فوري لكل الزوار'),
            ExpoCard(
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    enabled: active,
                    maxLength: 280,
                    decoration: expoInput(
                        active ? 'نص الإعلان' : 'متاح عندما يكون المعرض مجدولاً أو مباشراً',
                        hint: 'تبدأ الكلمة الرئيسية بعد 5 دقائق في القاعة A'),
                  ),
                ),
                const SizedBox(width: 10),
                expoButton(_sending ? '…' : 'إرسال',
                    active && !_sending ? _announce : null,
                    primary: true, icon: Icons.campaign_outlined),
              ]),
            ),

            // ===== البث =====
            expoTitle('البث المباشر والمجدول'),
            if (streams.isEmpty) expoEmpty('لا يوجد بث نشط أو مجدول'),
            ...streams.map((s) => ExpoCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    expoChip(s['status'] == 'live' ? 'مباشر' : 'مجدول',
                        s['status'] == 'live' ? Colors.red : Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s['title']}',
                              style: const TextStyle(
                                  fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
                          expoSub(s['booth_id'] != null
                              ? 'جناح: ${s['booths']?['name'] ?? ''}'
                              : 'جلسة'),
                        ],
                      ),
                    ),
                    expoSub('${s['current_viewers'] ?? 0} الآن · ذروة ${s['peak_viewers'] ?? 0}'),
                    const SizedBox(width: 8),
                    expoButton('مشاهدة',
                        () => expoOpen('/e/${widget.exhibition['slug']}/live/${s['id']}')),
                    expoButton('إشراف الدردشة',
                        () => expoOpen('/organizer/e/$_id/control')),
                  ]),
                )),

            // ===== الحظر =====
            expoTitle('المستخدمون المحظورون'),
            expoSub('الحظر يتم من الدردشة مباشرة أثناء الإشراف. هنا تُرفع القيود.'),
            const SizedBox(height: 8),
            if (bans.isEmpty) expoEmpty('لا يوجد محظورون'),
            ...bans.map((b) => ExpoCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b['user_id']}'.substring(0, 8),
                              style: const TextStyle(fontFamily: 'monospace')),
                          if (b['reason'] != null) expoSub('${b['reason']}'),
                        ],
                      ),
                    ),
                    expoSub(b['expires_at'] == null
                        ? 'دائم'
                        : 'حتى ${expoFmtDateTime(b['expires_at'])}'),
                    const SizedBox(width: 8),
                    expoButton('رفع الحظر', () => _unban('${b['user_id']}')),
                  ]),
                )),
          ],
        );
      },
    );
  }
}
