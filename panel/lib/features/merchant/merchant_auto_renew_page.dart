import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يُعرض مضمّناً داخل صفحة الاشتراكات
class MerchantAutoRenewPage extends StatefulWidget {
  const MerchantAutoRenewPage({super.key});

  @override
  State<MerchantAutoRenewPage> createState() => _MerchantAutoRenewPageState();
}

class _MerchantAutoRenewPageState extends State<MerchantAutoRenewPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final row = await supabase
          .from('merchant_subscriptions')
          .select()
          .eq('merchant_id', uid)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _sub = row == null ? null : Map<String, dynamic>.from(row);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Auto renew load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final res = await supabase
          .rpc('toggle_auto_renew', params: {'p_enabled': enabled});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack(
          enabled
              ? 'تم تفعيل التجديد التلقائي'
              : 'تم إيقاف التجديد التلقائي',
          enabled ? Colors.green : Colors.orange,
        );
      } else {
        _snack(map['error']?.toString() ?? 'تعذر التحديث', Colors.red);
      }
    } catch (e) {
      _snack('تعذر التحديث، حاول مجدداً', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return "${d.year}/${d.month}/${d.day}";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    if (_sub == null) return _empty();

    final enabled = _sub?['auto_renew'] == true;
    final isTrial = _sub?['is_trial'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusCard(enabled, isTrial),
        const SizedBox(height: 14),
        _infoCard(enabled),
      ],
    );
  }

  Widget _statusCard(bool enabled, bool isTrial) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (enabled ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.autorenew_rounded,
                    color: enabled ? Colors.green : Colors.grey, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enabled ? 'التجديد التلقائي مفعّل' : 'التجديد متوقف',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      (_sub?['plan_name'] ?? 'باقة').toString(),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (_saving || isTrial) ? null : _toggle,
                activeThumbColor: Colors.white,
                activeTrackColor: brandRed,
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 14),

          _line(
            enabled ? 'التجديد القادم' : 'ينتهي في',
            _fmt(_sub?['expires_at']),
          ),
          const SizedBox(height: 8),
          _line('المبلغ',
              '${((_sub?['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ر.س'),

          if (isTrial) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.blue, size: 17),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'أنت في فترة تجريبية — لا تجديد تلقائي عليها',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 1.7,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(bool enabled) {
    final points = enabled
        ? const [
            'يُجدَّد اشتراكك تلقائياً في تاريخ الانتهاء',
            'يبقى متجرك ظاهراً للعملاء بلا انقطاع',
            'يمكنك الإيقاف في أي وقت قبل موعد التجديد',
          ]
        : const [
            'لن يُجدَّد اشتراكك تلقائياً',
            'تختفي عروضك عن العملاء بعد تاريخ الانتهاء',
            'تبقى بياناتك محفوظة ويمكنك الاشتراك مجدداً',
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(enabled ? 'ماذا يعني ذلك' : 'ما الذي سيحدث',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      enabled
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_outline_rounded,
                      size: 16,
                      color: enabled ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              height: 1.8)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.autorenew_rounded,
              size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا يوجد اشتراك نشط',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
