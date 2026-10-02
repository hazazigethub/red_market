import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/app/app.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isBottomSheet;
  const LoginScreen({super.key, this.isBottomSheet = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // دالة إظهار رسالة الحظر بشكل احترافي
  void _showBannedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFD32027), size: 60),
              const SizedBox(height: 20),
              const Text(
                "تنبيه: الحساب محظور",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const SizedBox(height: 12),
              const Text(
                "نأسف لإبلاغك بأنه تم إيقاف نشاط هذا الحساب مؤقتاً لمخالفة سياسات الاستخدام. يرجى التواصل مع الدعم الفني للمزيد من المعلومات.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32027),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("حسناً",
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (mounted) setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final String phone =
          _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      final String password = _passwordController.text.trim();

      // يجلب بريد المصادقة المرتبط بالجوال — حقيقياً كان أو مولّداً
      String? authEmail;
      try {
        final res =
            await supabase.rpc('get_login_email', params: {'p_phone': phone});
        authEmail = res?.toString();
      } catch (e) {
        debugPrint('get_login_email error: $e');
      }

      if (authEmail == null || authEmail.isEmpty) {
        if (mounted) _showErrorSnackBar('لا يوجد حساب بهذا الرقم');
        return;
      }

      final response = await supabase.auth.signInWithPassword(
        email: authEmail,
        password: password,
      );

      if (!mounted || response.user == null) return;
      final user = response.user!;

      // ✅ التعديل: جلب حقل الحظر is_banned
      final userData = await supabase
          .from('profiles')
          .select('role, accepted_terms_version, is_banned')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null) {
        if (mounted) context.go(RoutePaths.home);
        return;
      }

      // ✅ التعديل: التحقق الفوري من حالة الحظر قبل الانتقال
      if (userData['is_banned'] == true) {
        await supabase.auth.signOut(); // تسجيل خروج فوري لإنهاء الجلسة
        if (mounted) _showBannedDialog();
        return;
      }

      final String userRole = userData['role']?.toString() ?? 'customer';
      final int acceptedVersion =
          int.tryParse(userData['accepted_terms_version']?.toString() ?? '0') ??
              0;

      ref.read(userRoleProvider.notifier).state = userRole;

      final latestTerms = await supabase
          .from('terms_content')
          .select('version, content')
          .eq('type', userRole.trim().toLowerCase())
          .maybeSingle();

      if (latestTerms != null) {
        final int serverVersion =
            int.tryParse(latestTerms['version']?.toString() ?? '0') ?? 0;

        if (acceptedVersion < serverVersion) {
          if (!mounted) return;
          const String targetPath = RoutePaths.customerTerms;

          context.go(targetPath, extra: {
            'content': latestTerms['content'],
            'version': serverVersion,
          });
          return;
        }
      }

      if (widget.isBottomSheet) {
        Navigator.pop(context, true);
      } else {
        if (userRole == 'merchant') {
          context.go(RoutePaths.home);
        } else if (userRole == 'super_admin') {
          context.go(RoutePaths.home);
        } else {
          context.go(RoutePaths.home);
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showErrorSnackBar(_mapAuthError(e.message));
    } catch (e) {
      debugPrint("Error during login check: $e");
      if (mounted) _showErrorSnackBar('حدث خطأ أثناء فحص البيانات');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String message) {
    if (message.contains("Invalid login credentials")) {
      return "رقم الهاتف أو كلمة المرور غير صحيحة";
    }
    return "فشل تسجيل الدخول، يرجى التحقق من الاتصال";
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Color(0xFFD32027);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: widget.isBottomSheet
          ? _buildLoginForm(mainColor)
          : Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildLoginForm(mainColor),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoginForm(Color mainColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isBottomSheet) ...[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "تسجيل الدخول",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Image.asset('assets/images/logo.png', width: 200, height: 200),
              const SizedBox(height: 20),
            ],
            _buildLabel("رقم الهاتف"),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: _buildInputDecoration(hint: "05xxxxxxxx"),
              validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
            ),
            const SizedBox(height: 15),
            _buildLabel("كلمة المرور"),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              textDirection: TextDirection.ltr,
              decoration: _buildInputDecoration(hint: "********").copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _performLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("دخول",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 16)),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                if (widget.isBottomSheet) Navigator.pop(context);
                context.push(RoutePaths.forgotPassword);
              },
              child: const Text("نسيت كلمة المرور؟",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (widget.isBottomSheet) Navigator.pop(context);
                context.push(RoutePaths.register);
              },
              child: const Text("ليس لديك حساب؟ سجل الآن",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _buildInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFD32027))),
    );
  }
}
