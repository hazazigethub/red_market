import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _brand = Color(0xFFD32027);

/// شاشة تأكيد البريد برمز — تُستعمل بعد إنشاء الحساب
class VerifyOtpScreen extends StatefulWidget {
  final String email;

  /// بيانات تُكتب في الملف بعد نجاح التحقّق (اختيارية)
  final Map<String, dynamic>? profileData;

  /// الوجهة بعد النجاح
  final Widget Function() onSuccess;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    required this.onSuccess,
    this.profileData,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpController = TextEditingController();
  bool _verifying = false;
  String? _error;
  int _resendIn = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_resendIn > 0) _resendIn--;
        if (_resendIn == 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _error = 'أدخل الرمز المكوّن من ستة أرقام');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      // الجلسة صارت نشطة — نكتب ما تبقّى من البيانات
      final user = supabase.auth.currentUser;
      if (user != null && widget.profileData != null) {
        final data = Map<String, dynamic>.from(widget.profileData!);
        data['id'] = user.id;
        try {
          await supabase.from('profiles').upsert(data);
        } catch (_) {
          // المشغّل كتب الأساسيات — فلا نُفشل التسجيل
        }
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => widget.onSuccess()),
        (route) => false,
      );
    } on AuthException {
      if (mounted) {
        setState(() => _error = 'الرمز غير صحيح أو منتهي الصلاحية');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر الاتصال، تحقق من الشبكة');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    setState(() => _error = null);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (!mounted) return;
      setState(() => _resendIn = 60);
      _startTimer();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إعادة الإرسال، حاول بعد قليل');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Image.asset('assets/images/logo.png',
                      width: 90, height: 90, fit: BoxFit.contain),
                ),
                const SizedBox(height: 24),

                const Text(
                  'تأكيد بريدك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _brand),
                ),
                const SizedBox(height: 12),

                Text(
                  'أرسلنا رمزاً من ستة أرقام إلى',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                ),

                const SizedBox(height: 28),

                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, letterSpacing: 12),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _brand, width: 1.8)),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, color: Colors.red),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _verifying ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _verifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('تأكيد',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 14),

                TextButton(
                  onPressed: _resendIn > 0 ? null : _resend,
                  child: Text(
                    _resendIn > 0
                        ? 'إعادة الإرسال بعد $_resendIn ثانية'
                        : 'إعادة إرسال الرمز',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _resendIn > 0 ? Colors.grey : _brand),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'لم تجد الرسالة؟ تحقّق من مجلد البريد المزعج.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
