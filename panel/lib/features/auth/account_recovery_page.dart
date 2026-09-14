import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تظهر عند دخول تاجر له طلب حذف قائم — يستعيد حسابه أو يمضي في الحذف
class AccountRecoveryPage extends StatefulWidget {
  final DateTime scheduledAt;
  final VoidCallback onRestored;

  const AccountRecoveryPage({
    super.key,
    required this.scheduledAt,
    required this.onRestored,
  });

  @override
  State<AccountRecoveryPage> createState() => _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends State<AccountRecoveryPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;
  bool _busy = false;

  int get _daysLeft {
    final d = widget.scheduledAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  String get _dateLabel {
    final d = widget.scheduledAt;
    return "${d.year}/${d.month}/${d.day}";
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final res = await supabase.rpc('cancel_account_deletion');
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تمت استعادة حسابك',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ));
        // تأخير بسيط ليقرأ المستخدم الرسالة، ثم خروج ودخول جديد
        await Future.delayed(const Duration(milliseconds: 900));
        await supabase.auth.signOut();

        if (!mounted) return;
        widget.onRestored();
      } else {
        _snack(map['error']?.toString() ?? 'تعذرت الاستعادة');
      }
    } catch (e) {
      _snack('تعذرت الاستعادة، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: Colors.red,
    ));
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEDEFF3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_busy_rounded,
                              color: Colors.orange, size: 34),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'حسابك مجدول للحذف',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'سيُحذف حسابك نهائياً في $_dateLabel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          height: 1.8,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$_daysLeft',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              _daysLeft == 1 ? 'يوم متبقٍ' : 'يوماً متبقياً',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),
                      const Divider(color: Color(0xFFEDEFF3)),
                      const SizedBox(height: 16),

                      ...const [
                        'متجرك موقوف حالياً ولا تظهر عروضك للعملاء',
                        'بياناتك وعروضك ما زالت محفوظة',
                        'يمكنك استعادة حسابك الآن ويعود كما كان',
                        'بعد انتهاء المدة يُحذف الحساب ولا يمكن استرجاعه',
                      ].map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.circle,
                                    size: 6, color: Colors.grey),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      height: 1.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.restore_rounded, size: 19),
                        label: Text(
                          _busy ? 'جاري الاستعادة...' : 'استعادة حسابي',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextButton(
                        onPressed: _busy ? null : _signOut,
                        child: Text(
                          'متابعة الحذف والخروج',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
