import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _supabase = Supabase.instance.client;
  bool _confirmDeletion = false;
  bool _isLoading = false; // متغير لحالة التحميل

  // دالة الحذف الفعلية
  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      // استدعاء دالة قاعدة البيانات لحذف المستخدم
      // ملاحظة: تأكد من إنشاء الدالة delete_user في SQL Editor كما هو موضح أعلاه
      await _supabase.rpc('delete_user');

      // بدلاً من ذلك، إذا لم تستخدم دالة RPC، يمكنك فقط تسجيل الخروج
      // ولكن الحذف الحقيقي يتطلب صلاحيات Admin أو دالة خاصة
      // await _supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حذف الحساب بنجاح"),
            backgroundColor: Colors.green,
          ),
        );
        // التوجيه لصفحة تسجيل الدخول وإزالة كل الصفحات السابقة
        context.go(RoutePaths.login);
      }
    } on PostgrestException catch (e) {
      _showError("فشل الحذف: ${e.message}");
    } catch (e) {
      _showError("حدث خطأ غير متوقع. حاول مرة أخرى.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text("حذف الحساب",
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 100, color: Colors.red),
                      const SizedBox(height: 30),
                      const Text(
                        "هل أنت متأكد من حذف حسابك؟",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "بمجرد تأكيد الحذف، سيتم مسح كافة بياناتك، طلباتك السابقة، ونقاط الولاء بشكل نهائي. لا يمكن التراجع عن هذه الخطوة لاحقاً.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.8,
                            fontFamily: 'Cairo',
                            color: isDark ? Colors.white70 : Colors.grey[700]),
                      ),
                      const SizedBox(height: 40),
                      CheckboxListTile(
                        value: _confirmDeletion,
                        onChanged: (val) =>
                            setState(() => _confirmDeletion = val!),
                        activeColor: Colors.red,
                        title: const Text(
                          "أدرك أن هذا الإجراء نهائي ولا يمكن استعادة البيانات.",
                          style: TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: (_confirmDeletion && !_isLoading)
              ? _deleteAccount // استدعاء دالة الحذف
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
            minimumSize: const Size(double.infinity, 55),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text("تأكيد الحذف النهائي",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo')),
        ),
        const SizedBox(height: 15),
        TextButton(
          onPressed: _isLoading ? null : () => context.pop(),
          child: const Text("إلغاء، العودة للملف الشخصي",
              style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}
