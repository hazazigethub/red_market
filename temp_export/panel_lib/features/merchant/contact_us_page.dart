import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMerchantMessage() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      _snack('يرجى كتابة الموضوع وتفاصيل الرسالة', Colors.orange);
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'يجب تسجيل الدخول أولاً';

      await supabase.from('reports').insert({
        'reporter_id': user.id,
        'target_type': 'merchant_support',
        'target_name': subject,
        'reason': message,
        'status': 'pending',
      });

      if (!mounted) return;
      _snack('تم إرسال طلبك، سيتم الرد عليك قريباً', Colors.green);
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      _snack('تعذر الإرسال، حاول مجدداً', Colors.red);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'تواصل معنا',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'فريق دعم المتاجر جاهز لمساعدتك',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ===== قنوات التواصل =====
                    LayoutBuilder(
                      builder: (context, c) {
                        const gap = 12.0;
                        final cols = c.maxWidth >= 560 ? 2 : 1;
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        final items = [
                          _channel(
                            isDark: isDark,
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'واتساب الدعم',
                            value: '( رقم الواتساب )',
                          ),
                          _channel(
                            isDark: isDark,
                            icon: Icons.mail_outline_rounded,
                            title: 'البريد الإلكتروني',
                            value: '( البريد الإلكتروني )',
                          ),
                        ];

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: items
                              .map((e) => SizedBox(width: w, child: e))
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 26),

                    // ===== نموذج الرسالة =====
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? Colors.white10
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
                                  color: brandRed.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.support_agent_rounded,
                                    color: brandRed, size: 19),
                              ),
                              const SizedBox(width: 12),
                              const Text('أرسل طلب دعم',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          _field(
                            controller: _subjectController,
                            label: 'الموضوع',
                            hint: 'مثال: استفسار عن الباقة',
                            icon: Icons.title_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _messageController,
                            label: 'تفاصيل الرسالة',
                            hint: 'اكتب استفسارك أو مشكلتك بوضوح',
                            icon: Icons.notes_rounded,
                            isDark: isDark,
                            maxLines: 5,
                          ),

                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendMerchantMessage,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _isSending ? 'جاري الإرسال...' : 'إرسال الرسالة',
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: brandRed.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 16, color: brandRed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'نرد على طلبات الدعم خلال 24 ساعة في أيام العمل',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                height: 1.7,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _channel({
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: brandRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: brandRed, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: brandRed, size: 19),
            filled: true,
            fillColor:
                isDark ? Colors.white10 : const Color(0xFFF7F8FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
