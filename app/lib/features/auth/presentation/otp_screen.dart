import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final bool isMerchant;

  const OtpScreen(
      {super.key, required this.phoneNumber, required this.isMerchant});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _secondsRemaining = 30;
  Timer? _timer;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ✅ تفعيل التحقق التقني للعميل والتاجر
  Future<void> _verifyOtp() async {
    String code = _controllers.map((e) => e.text).join();

    if (code.length < 4) {
      _showSnackBar("الرجاء إدخال الرمز كاملاً");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1️⃣ التحقق من الرمز تقنياً عبر SMS
      final response = await supabase.auth.verifyOTP(
        phone: widget.phoneNumber,
        token: code,
        type: OtpType.sms,
      );

      if (!mounted) return;

      if (response.user == null) {
        // لم يُرجع الخادم مستخدماً: فشل صامت سابقاً، الآن يُبلَّغ المستخدم
        _showSnackBar("تعذر إتمام التحقق، حاول مجدداً");
        return;
      }

      context.go(RoutePaths.home);
    } on AuthException catch (e) {
      debugPrint("OTP verify AuthException: ${e.message}");
      _showSnackBar(
          e.message.isNotEmpty ? e.message : "رمز غير صحيح أو منتهي الصلاحية");
    } catch (e, st) {
      debugPrint("OTP verify error: $e\n$st");
      _showSnackBar("فشل التحقق التقني، حاول مجدداً");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await supabase.auth.signInWithOtp(phone: widget.phoneNumber);
      if (!mounted) return;
      _startTimer();
      _showSnackBar("تم إرسال رمز جديد لهاتفك");
    } on AuthException catch (e) {
      debugPrint("OTP resend AuthException: ${e.message}");
      _showSnackBar(e.message.isNotEmpty
          ? e.message
          : "لا يمكن إعادة الإرسال الآن، حاول لاحقاً");
    } catch (e, st) {
      debugPrint("OTP resend error: $e\n$st");
      _showSnackBar("تعذر إرسال الرمز، تحقق من الاتصال");
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(RoutePaths.login),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_outlined,
                  size: 80, color: brandRed),
              const SizedBox(height: 20),
              const Text(
                "التحقق التقني",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 8),
              Text(
                "أدخل الرمز المرسل إلى\n${widget.phoneNumber}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    height: 1.5,
                    fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 40),

              // خانات OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 65,
                    height: 65,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      autofocus: index == 0,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: brandRed, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 3) {
                          FocusScope.of(context)
                              .requestFocus(_focusNodes[index + 1]);
                        } else if (value.isEmpty && index > 0) {
                          FocusScope.of(context)
                              .requestFocus(_focusNodes[index - 1]);
                        }
                        if (index == 3 && value.isNotEmpty) {
                          FocusScope.of(context).unfocus();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("تأكيد وفتح الحساب",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo')),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("لم يصلك الرمز؟ ",
                      style:
                          TextStyle(color: Colors.black, fontFamily: 'Cairo')),
                  _secondsRemaining > 0
                      ? Text(
                          "إعادة إرسال خلال $_secondsRemaining ث",
                          style: const TextStyle(
                              color: brandRed,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                        )
                      : TextButton(
                          onPressed: _isResending ? null : _resendCode,
                          child: const Text("إعادة إرسال الآن",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: brandRed,
                                  fontFamily: 'Cairo')),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
