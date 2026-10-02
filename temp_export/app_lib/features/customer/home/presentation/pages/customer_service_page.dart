import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ إضافة سوبابيس
import 'package:red_market/core/routing/route_paths.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerServicePage extends StatefulWidget {
  // ✅ تم التحويل لـ StatefulWidget للتحكم بالبيانات
  const CustomerServicePage({super.key});

  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage> {
  // ✅ تعريف الـ Controllers والـ Supabase
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/message/4ZYS4PCSKP5BA1');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ✅ دالة إرسال الرسالة لقاعدة البيانات
  Future<void> _sendMessage() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("يرجى كتابة الموضوع وتفاصيل الرسالة",
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "يجب تسجيل الدخول أولاً لإرسال رسالة";

      await supabase.from('reports').insert({
        'reporter_id': user.id,
        'target_type': 'user_support', // لكي تظهر في قسم خدمة العملاء باللوحة
        'target_name': subject, // موضوع الرسالة
        'reason': message, // نص الرسالة
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إرسال رسالتك، سنتواصل معك قريباً ✅",
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("حدث خطأ أثناء الإرسال: $e",
                  style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color brandGreen = Theme.of(context).colorScheme.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text("خدمة العملاء",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeaderIcon(brandGreen),
              const SizedBox(height: 30),

              _buildContactCard(context, "تواصل عبر واتساب",
                  Icons.chat_bubble_outline, Colors.green,
                  onTap: _openWhatsApp, fullWidth: true),

              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerRight,
                child: Text("أرسل لنا رسالة",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: 'Cairo')),
              ),
              const SizedBox(height: 20),

              // نموذج التواصل المربوط بالـ Controllers
              _buildTextField("موضوع الرسالة", Icons.subject, isDark,
                  controller: _subjectController),
              const SizedBox(height: 15),
              _buildTextField(
                  "تفاصيل المشكلة أو الاستفسار", Icons.message_outlined, isDark,
                  maxLines: 5, controller: _messageController),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSending ? null : _sendMessage, // ربط الدالة بالزر
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("إرسال الآن",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(Icons.headset_mic_rounded, size: 60, color: color),
    );
  }

  Widget _buildContactCard(
      BuildContext context, String title, IconData icon, Color color,
      {bool fullWidth = false, VoidCallback? onTap}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Widget cardContent = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
    final wrapped =
        fullWidth ? cardContent : Expanded(flex: 1, child: cardContent);
    return onTap != null
        ? GestureDetector(onTap: onTap, child: wrapped)
        : wrapped;
  }

  Widget _buildTextField(String hint, IconData icon, bool isDark,
      {int maxLines = 1, TextEditingController? controller}) {
    return TextFormField(
      controller: controller, // تمرير الكنترولر للحقل
      maxLines: maxLines,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor:
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }
}
