import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/features/customer/home/presentation/pages/interests_selection_screen.dart';
import 'package:red_market/app/app_providers.dart';
import 'package:red_market/features/auth/presentation/verify_otp_screen.dart';

bool isRegisteringInProgress = false;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  static bool _isRegistering = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedGender = 'male';
  bool _isTermsAccepted = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isTermsAccepted) {
      _showError("⚠️ يرجى الموافقة على الشروط والأحكام أولاً");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("⚠️ كلمات المرور غير متطابقة");
      return;
    }

    final pwErr = passwordError(_passwordController.text.trim());
    if (pwErr != null) {
      _showError("⚠️ $pwErr");
      return;
    }

    setState(() => _isLoading = true);
    isRegisteringInProgress = true;

    try {
      final supabase = Supabase.instance.client;
      final String rawPhone = _phoneController.text.trim();
      final String cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');

      final String email = _emailController.text.trim().toLowerCase();
      final String password = _passwordController.text.trim();

      ref.read(userRoleProvider.notifier).state = 'customer';

      // فحص مسبق — فالتسجيل المكرّر يفشل صامتاً في Supabase
      final avail = await supabase.rpc(
        'check_signup_availability',
        params: {'p_email': email, 'p_phone': cleanPhone},
      ) as Map<String, dynamic>;

      if (avail['email_taken'] == true) {
        _showError("هذا البريد مسجّل مسبقاً — سجّل دخولك أو استعد كلمة المرور");
        return;
      }
      if (avail['phone_taken'] == true) {
        _showError("رقم الجوال مسجّل بحساب آخر — سجّل دخولك أو استخدم رقماً غيره");
        return;
      }

      // البيانات تُمرَّر للمشغّل — فلا جلسة قبل التأكيد
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'customer',
          'full_name': _nameController.text.trim(),
          'phone_number': cleanPhone,
          'gender': _selectedGender,
        },
      );

      int latestTermsVersion = 0;
      try {
        final termsData = await supabase
            .from('terms_content')
            .select('version')
            .eq('type', 'customer')
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        latestTermsVersion =
            int.tryParse(termsData?['version']?.toString() ?? '0') ?? 0;
      } catch (_) {}

      if (!mounted) return;

      // بقية البيانات تُكتب بعد نجاح التحقّق
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            email: email,
            profileData: {
              'full_name': _nameController.text.trim(),
              'phone_number': cleanPhone,
              'email_contact': email,
              'gender': _selectedGender,
              'accepted_terms_version': latestTermsVersion,
            },
            onSuccess: () => const InterestsSelectionScreen(),
          ),
        ),
      );
    } on AuthException catch (e) {
      _showError("خطأ في التسجيل: ${e.message}");
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('profiles_phone_number_unique')) {
        _showError("⚠️ رقم الجوال مسجل مسبقاً، يرجى تسجيل الدخول");
      } else {
        _showError("حدث خطأ غير متوقع: $e");
      }

      isRegisteringInProgress = false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color activeColor = Color(0xFFD32027);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text("إنشاء حساب عميل",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel("الاسم الكامل"),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: _inputDecoration(
                      hint: "مثال: محمد أحمد", icon: Icons.person_outline),
                  validator: (val) =>
                      (val == null || val.isEmpty) ? "الاسم مطلوب" : null,
                ),
                const SizedBox(height: 15),
                _buildLabel("الجنس"),
                Row(
                  children: [
                    Expanded(
                        child: _buildGenderOption("ذكر",
                            'assets/avatars/man.svg', 'male', Colors.blue)),
                    const SizedBox(width: 15),
                    Expanded(
                        child: _buildGenderOption("أنثى",
                            'assets/avatars/woman.svg', 'female',
                            Colors.pink)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildLabel("رقم الهاتف"),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: _inputDecoration(
                      hint: "05xxxxxxxx", icon: Icons.phone_android),
                  validator: (val) => (val == null || val.length < 9)
                      ? "رقم الهاتف مطلوب بشكل صحيح"
                      : null,
                ),
                const SizedBox(height: 15),
                _buildLabel("البريد الإلكتروني"),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: _inputDecoration(
                      hint: "name@example.com",
                      icon: Icons.alternate_email_rounded),
                  validator: (val) {
                    final v = (val ?? '').trim();
                    if (v.isEmpty) return "البريد الإلكتروني مطلوب";
                    final ok = RegExp(
                            r'^[\w.\-+]+@[\w\-]+(\.[\w\-]+)+$')
                        .hasMatch(v);
                    return ok ? null : "بريد إلكتروني غير صحيح";
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  "يُستخدم لاستعادة كلمة السر — تأكد من صحته",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600),
                ),
                const SizedBox(height: 15),
                _buildLabel("كلمة السر"),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: _inputDecoration(
                    hint: "**********",
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _buildLabel("تأكيد كلمة السر"),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: _inputDecoration(
                    hint: "**********",
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _isTermsAccepted,
                        activeColor: activeColor,
                        onChanged: (val) =>
                            setState(() => _isTermsAccepted = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "أوافق على ",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () => context.push(RoutePaths.customerTerms),
                      child: const Text(
                        "الشروط والأحكام",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: activeColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isTermsAccepted)
                        ? null
                        : _handleRegister,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("إنشاء الحساب",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 15),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("لديك حساب بالفعل؟ ",
                        style:
                            TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                    GestureDetector(
                        onTap: () => context.go(RoutePaths.login),
                        child: const Text("تسجيل الدخول",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: activeColor,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(
      String label, String asset, String value, Color color) {
    final isSelected = _selectedGender == value;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => setState(() => _selectedGender = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SvgPicture.asset(asset, width: 44, height: 44),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 5),
      child: Text(text,
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)));

  InputDecoration _inputDecoration(
      {required String hint, IconData? icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: Colors.grey[600]) : null,
      suffixIcon: suffixIcon,
      hintStyle:
          TextStyle(fontFamily: 'Cairo', color: Colors.grey[400], fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32027), width: 1.5)),
    );
  }
}

/// ٨ خانات على الأقل، مع حرف كبير وصغير ورقم ورمز
String? passwordError(String pw) {
  if (pw.length < 8) return 'كلمة المرور يجب أن تكون 8 خانات على الأقل';
  if (!RegExp(r'[a-z]').hasMatch(pw)) {
    return 'أضف حرفاً إنجليزياً صغيراً على الأقل';
  }
  if (!RegExp(r'[A-Z]').hasMatch(pw)) {
    return 'أضف حرفاً إنجليزياً كبيراً على الأقل';
  }
  if (!RegExp(r'[0-9]').hasMatch(pw)) return 'أضف رقماً على الأقل';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) {
    return 'أضف رمزاً مثل ! أو @ أو #';
  }
  return null;
}
