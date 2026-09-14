import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/otp_verification_page.dart';

class MerchantCancelSubscriptionPage extends StatefulWidget {
  const MerchantCancelSubscriptionPage({super.key});

  @override
  State<MerchantCancelSubscriptionPage> createState() =>
      _MerchantCancelSubscriptionPageState();
}

class _MerchantCancelSubscriptionPageState
    extends State<MerchantCancelSubscriptionPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _sub;

  /// أهلية الاسترداد
  bool _refundEligible = false;
  int _refundWindow = 7;
  double _refundAmount = 0;
  String _phone = '';

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

      // بيانات الجوال لرمز التحقق
      final profile = await supabase
          .from('profiles')
          .select('phone_number')
          .eq('id', uid)
          .maybeSingle();

      bool eligible = false;
      int window = 7;
      double amount = 0;

      if (row != null) {
        final sub = Map<String, dynamic>.from(row);
        final price = (sub['price'] as num?)?.toDouble() ?? 0;
        final isTrial = sub['is_trial'] == true;
        final billing = (sub['billing'] ?? 'monthly').toString();
        final started = DateTime.tryParse(
            (sub['started_at'] ?? '').toString());

        window = billing == 'yearly' ? 14 : 7;
        amount = price;

        if (!isTrial && price > 0 && started != null) {
          final daysUsed = DateTime.now().difference(started).inDays;
          eligible = daysUsed <= window;
        }
      }

      if (mounted) {
        setState(() {
          _sub = row == null ? null : Map<String, dynamic>.from(row);
          _refundEligible = eligible;
          _refundWindow = window;
          _refundAmount = amount;
          _phone = (profile?['phone_number'] ?? '').toString();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Cancel page load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return "${d.year}/${d.month}/${d.day}";
  }

  void _confirm() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('تأكيد الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'سيبقى اشتراكك فعّالاً حتى ${_fmt(_sub?['expires_at'])}، '
              'ثم تختفي عروضك عن العملاء ولن يُجدَّد تلقائياً.',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _cancel();
              },
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// يفتح رمز التحقق ثم ينفّذ الاسترداد
  void _startRefund() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OtpVerificationPage(
        title: 'تأكيد الاسترداد',
        subtitle: 'أدخل الرمز المرسل لتأكيد إلغاء اشتراكك واسترداد مبلغك',
        phoneNumber: _phone,
        onVerified: _doRefund,
      ),
    );
  }

  Future<void> _doRefund() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final res = await supabase.rpc('request_refund');
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Text('تم استلام طلبك',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              content: Text(
                'أُلغي اشتراكك واختفت عروضك عن العملاء.\n'
                'ستتم معالجة استرداد مبلغك خلال 48 ساعة.',
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        );
      } else {
        _snack(map['error']?.toString() ?? 'تعذر تنفيذ الطلب', Colors.red);
      }
    } catch (e) {
      _snack('تعذر تنفيذ الطلب، حاول مجدداً', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final res = await supabase.rpc('cancel_subscription');
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack('تم إلغاء التجديد — اشتراكك فعّال حتى نهاية المدة',
            Colors.orange);
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الإلغاء', Colors.red);
      }
    } catch (e) {
      _snack('تعذر الإلغاء، حاول مجدداً', Colors.red);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    if (_sub == null) return _empty();

    final cancelled = _sub?['cancelled_at'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: cancelled
                    ? Colors.orange.withValues(alpha: 0.4)
                    : const Color(0xFFEDEFF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: (cancelled ? Colors.orange : brandRed)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                        cancelled
                            ? Icons.event_busy_rounded
                            : Icons.cancel_outlined,
                        color: cancelled ? Colors.orange : brandRed,
                        size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cancelled ? 'الاشتراك ملغى' : 'اشتراكك نشط',
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
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: Color(0xFFEDEFF3), height: 1),
              const SizedBox(height: 14),

              Row(
                children: [
                  Text(cancelled ? 'فعّال حتى' : 'ينتهي في',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: Colors.grey.shade600)),
                  const Spacer(),
                  Text(_fmt(_sub?['expires_at']),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ما الذي سيحدث عند الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...const [
                'يبقى اشتراكك فعّالاً حتى نهاية المدة المدفوعة',
                'تختفي عروضك ومقاطعك عن العملاء بعدها',
                'تبقى بياناتك محفوظة ويمكنك الاشتراك مجدداً',
                'لا استرداد للمبلغ المدفوع عن المدة المتبقية',
              ].map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.remove_circle_outline_rounded,
                            size: 16, color: Colors.orange),
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

              const SizedBox(height: 8),

              // بطاقة الاسترداد — داخل المدة فقط
              if (_refundEligible && !cancelled) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.replay_circle_filled_rounded,
                              color: Colors.green, size: 19),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text('يمكنك استرداد مبلغك كاملاً',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Text('${_refundAmount.toStringAsFixed(0)} ر.س',
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'مدة الاسترداد $_refundWindow أيام من تاريخ الاشتراك. '
                        'عند الاسترداد يُلغى اشتراكك فوراً وتختفي عروضك.',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            height: 1.8,
                            color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _startRefund,
                          icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18),
                          label: Text(
                              _saving
                                  ? 'جاري المعالجة...'
                                  : 'إلغاء واسترداد المبلغ',
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (cancelled)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.orange, size: 17),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ألغيت التجديد. لإعادته، فعّل التجديد التلقائي.',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              height: 1.7,
                              color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _confirm,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                        _saving ? 'جاري الإلغاء...' : 'إلغاء الاشتراك',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.cancel_outlined, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا يوجد اشتراك نشط',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
