import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../expo_common.dart';

const Map<String, String> kCodeProduct = {
  'participation': 'المشاركة في معرض',
  'recording': 'تسجيل البث',
};

/// الأسعار وأكواد المعارض
class PricingTab extends StatefulWidget {
  const PricingTab({super.key});

  @override
  State<PricingTab> createState() => _PricingTabState();
}

class _PricingTabState extends State<PricingTab> {
  final _participation = TextEditingController();
  final _recording = TextEditingController();
  bool _savingFees = false;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _participation.dispose();
    _recording.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final settings = await expoDb.from('settings').select('key, value');
    final codes = await expoDb
        .from('promo_codes')
        .select('*')
        .order('created_at', ascending: false);
    final used = await expoDb.from('participation_purchases').select('promo_code');
    final fee = <String, String>{};
    for (final r in settings) {
      fee['${r['key']}'] = '${r['value']}';
    }
    _participation.text = fee['participation_fee'] ?? '100';
    _recording.text = fee['recording_fee'] ?? '175';
    final counts = <String, int>{};
    for (final r in used) {
      final c = '${r['promo_code'] ?? ''}'.toLowerCase();
      if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
    }
    return {'codes': codes, 'counts': counts};
  }

  void _reload() => setState(() => _future = _load());

  // ===================== الأسعار =====================

  Future<void> _saveFees() async {
    final p = int.tryParse(_participation.text.trim());
    final r = int.tryParse(_recording.text.trim());
    if (p == null || p < 0 || r == null || r < 0) {
      return expoToast(context, 'السعر رقم صحيح 0 أو أكثر', warn: true);
    }
    setState(() => _savingFees = true);
    final now = DateTime.now().toUtc().toIso8601String();
    await expoRun(context, () async {
      await expoDb.from('settings').update({'value': p, 'updated_at': now}).eq('key', 'participation_fee');
      await expoDb.from('settings').update({'value': r, 'updated_at': now}).eq('key', 'recording_fee');
    }, ok: 'حُفظت الأسعار');
    if (mounted) setState(() => _savingFees = false);
  }

  Widget _feesCard() => ExpoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            expoFormSection('الأسعار', Icons.sell_outlined, note: 'بالريال'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _participation,
                  keyboardType: TextInputType.number,
                  style: kExpoFieldText,
                  decoration: expoInput('رسوم المشاركة في المعرض',
                      icon: Icons.storefront_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _recording,
                  keyboardType: TextInputType.number,
                  style: kExpoFieldText,
                  decoration:
                      expoInput('رسوم تسجيل البث', icon: Icons.videocam_outlined),
                ),
              ),
              expoButton(_savingFees ? 'جاري الحفظ...' : 'حفظ',
                  _savingFees ? null : _saveFees,
                  primary: true, icon: Icons.check_rounded),
            ]),
            const SizedBox(height: 8),
            expoSub('الباقة الاحترافية السنوية: مشاركة مجانية واحدة لكل فترة اشتراك.'),
          ],
        ),
      );

  // ===================== الأكواد =====================

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return 'EXPO-${List.generate(6, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  Future<void> _newCode() async {
    final code = TextEditingController(text: _randomCode());
    final percent = TextEditingController(text: '100');
    String product = 'participation';
    DateTime? expires;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: expoDialogTitle('كود جديد', Icons.confirmation_number_outlined),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, minWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: product,
                  decoration: expoInput('الخدمة', icon: Icons.category_outlined),
                  items: kCodeProduct.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: const TextStyle(fontFamily: kExpoFont, fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setD(() => product = v ?? 'participation'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: code,
                  textDirection: TextDirection.ltr,
                  style: kExpoFieldText,
                  decoration: expoInput('الكود', icon: Icons.confirmation_number_outlined),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: percent,
                  keyboardType: TextInputType.number,
                  style: kExpoFieldText,
                  decoration: expoInput('نسبة الخصم %', icon: Icons.percent_rounded),
                ),
                const SizedBox(height: 6),
                expoSub('حالياً يعمل كود 100% فقط، لعدم ربط بوابة الدفع.'),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: expires ?? now.add(const Duration(days: 30)),
                        firstDate: now,
                        lastDate: DateTime(now.year + 3));
                    if (d != null) setD(() => expires = d);
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
                          expires == null
                              ? 'تاريخ الانتهاء — بدون'
                              : 'ينتهي: ${expires!.day}/${expires!.month}/${expires!.year}',
                          style: TextStyle(
                              fontFamily: kExpoFont,
                              fontSize: 12.5,
                              color: expires == null ? Colors.grey.shade500 : kInk),
                        ),
                      ),
                      if (expires != null)
                        InkWell(
                          onTap: () => setD(() => expires = null),
                          child: Icon(Icons.close_rounded,
                              size: 17, color: Colors.grey.shade500),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء',
                      style: TextStyle(fontFamily: kExpoFont, color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إنشاء',
                    style: TextStyle(
                        fontFamily: kExpoFont,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
    final c = code.text.trim().toUpperCase();
    final pct = int.tryParse(percent.text.trim()) ?? 0;
    code.dispose();
    percent.dispose();
    if (go != true || !mounted) return;
    if (c.length < 3) return expoToast(context, 'الكود 3 أحرف على الأقل', warn: true);
    if (pct < 1 || pct > 100) return expoToast(context, 'النسبة بين 1 و100', warn: true);
    final ok = await expoRun(
        context,
        () => expoDb.from('promo_codes').insert({
              'code': c,
              'product': product,
              'discount_percent': pct,
              'expires_at': expires == null
                  ? null
                  : DateTime(expires!.year, expires!.month, expires!.day, 23, 59)
                      .toUtc()
                      .toIso8601String(),
            }),
        ok: 'أُنشئ الكود');
    if (ok) _reload();
  }

  Future<void> _toggle(Map<String, dynamic> c) async {
    final ok = await expoRun(
        context,
        () => expoDb
            .from('promo_codes')
            .update({'is_active': c['is_active'] != true}).eq('id', c['id']),
        ok: c['is_active'] == true ? 'أُوقف الكود' : 'فُعّل الكود');
    if (ok) _reload();
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    if (!await expoConfirm(context, 'حذف الكود', 'سيُحذف الكود «${c['code']}» نهائياً.',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await expoRun(
        context, () => expoDb.from('promo_codes').delete().eq('id', c['id']),
        ok: 'حُذف الكود');
    if (ok) _reload();
  }

  Widget _codeCard(Map<String, dynamic> c, int used) {
    final active = c['is_active'] == true;
    final expiresAt = c['expires_at'] == null ? null : DateTime.tryParse('${c['expires_at']}');
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final (String label, Color color) = !active
        ? ('موقوف', Colors.grey)
        : expired
            ? ('منتهٍ', Colors.orange)
            : ('فعّال', Colors.green);
    return ExpoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: SelectableText('${c['code']}',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
            expoChip(label, color),
            const SizedBox(width: 4),
            expoIconAction(Icons.copy_rounded, () async {
              await Clipboard.setData(ClipboardData(text: '${c['code']}'));
              if (mounted) expoToast(context, 'نُسخ الكود');
            }, tooltip: 'نسخ'),
            expoDelete(() => _delete(c)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 18, runSpacing: 6, children: [
            expoStat(Icons.category_outlined, kCodeProduct['${c['product']}'] ?? ''),
            expoStat(Icons.percent_rounded, '${c['discount_percent']}%'),
            expoStat(Icons.how_to_reg_outlined, 'استُخدم $used مرة'),
            expoStat(Icons.schedule_rounded,
                expiresAt == null ? 'بدون انتهاء' : 'ينتهي ${expoFmtDate(c['expires_at'])}'),
          ]),
          const SizedBox(height: 10),
          kExpoDivider,
          const SizedBox(height: 4),
          expoSwitch(active ? 'الكود يعمل' : 'الكود موقوف', active, (_) => _toggle(c)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return expoLoader();
        if (snap.hasError) return expoFailed(snap.error);
        final codes = List<Map<String, dynamic>>.from(snap.data!['codes'] as List);
        final counts = snap.data!['counts'] as Map<String, int>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _feesCard(),
            const SizedBox(height: 18),
            expoHeader('الأكواد', count: codes.length,
                subtitle: 'يُدخلها التاجر عند الشراء، ويُستخدم الكود مرة واحدة لكل تاجر',
                actions: [
                  expoButton('كود جديد', _newCode, primary: true, icon: Icons.add_rounded),
                ]),
            if (codes.isEmpty)
              expoEmpty('لا أكواد بعد', icon: Icons.confirmation_number_outlined)
            else
              expoGrid(codes
                  .map((c) => _codeCard(c, counts['${c['code']}'.toLowerCase()] ?? 0))
                  .toList()),
          ],
        );
      },
    );
  }
}
