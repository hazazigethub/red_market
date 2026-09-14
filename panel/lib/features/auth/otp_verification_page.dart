import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// صفحة تحقّق برمز — تدعم نمطين:
///
/// • **البريد** (`email` غير فارغ) — تحقّق حقيقي عبر Supabase، ست خانات،
///   وتُعرض كصفحة كاملة. تُستعمل عند تأكيد التسجيل.
///
/// • **الجوال** (`phoneNumber` غير فارغ) — تحقّق شكليّ بانتظار مزوّد الرسائل،
///   أربع خانات، وتُعرض كنافذة. تُستعمل عند إلغاء الاشتراك.
class OtpVerificationPage extends StatefulWidget {
  final String title;
  final String subtitle;

  /// البريد — وجوده يعني تحقّقاً حقيقياً
  final String? email;

  /// الجوال — يُعرض فقط في النمط الشكليّ
  final String? phoneNumber;

  /// يُنفَّذ بعد نجاح التحقّق
  final FutureOr<void> Function() onVerified;

  /// رسالة تظهر بعد النجاح — في نمط البريد فقط
  final String successMessage;

  const OtpVerificationPage({
    super.key,
    this.title = 'رمز التحقق',
    required this.subtitle,
    required this.onVerified,
    this.email,
    this.phoneNumber,
    this.successMessage = 'تم إنشاء الحساب بنجاح',
  }) : assert(email != null || phoneNumber != null,
            'يلزم بريد أو جوال');

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  static const Color brandRed = Color(0xFFD32027);

  /// البريد ⇒ ست خانات وتحقّق حقيقي · الجوال ⇒ أربع وشكليّ
  bool get _isEmail => widget.email != null && widget.email!.isNotEmpty;
  int get _digits => _isEmail ? 6 : 4;
  int get _waitSeconds => _isEmail ? 60 : 120;

  late final List<TextEditingController> _controllers =
      List.generate(_digits, (_) => TextEditingController());
  late final List<FocusNode> _nodes =
      List.generate(_digits, (_) => FocusNode());

  Timer? _timer;
  int _remaining = 0;
  bool _canResend = false;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _remaining = _waitSeconds;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _canResend = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  String get _timeLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < _digits - 1) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (_code.length < _digits || _verifying) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      if (_isEmail) {
        await Supabase.instance.client.auth.verifyOTP(
          email: widget.email!,
          token: _code,
          type: OtpType.signup,
        );

        // الجلسة قائمة — ننفّذ ما تبقّى من الإعداد
        await widget.onVerified();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.successMessage,
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        // ⚠️ محاكاة تحقق — يُستبدل باستدعاء مزوّد الرسائل
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        Navigator.pop(context);
        await widget.onVerified();
      }
    } on AuthException {
      if (mounted) {
        setState(() => _error = 'الرمز غير صحيح أو منتهي الصلاحية');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر إكمال العملية: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;

    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    setState(() => _error = null);

    if (_isEmail) {
      try {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: widget.email!,
        );
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'تعذر إعادة الإرسال، حاول بعد قليل');
        }
        return;
      }
    }

    if (!mounted) return;
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          _isEmail ? 'أُرسل رمز جديد إلى بريدك' : 'أُرسل رمز جديد إلى جوالك',
          style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: brandRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: _isEmail
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: brandRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  _isEmail ? Icons.mark_email_read_outlined
                           : Icons.sms_outlined,
                  color: brandRed,
                  size: 26),
            ),
            const SizedBox(height: 16),

            Text(widget.title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  height: 1.8,
                  color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),

            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _isEmail ? widget.email! : (widget.phoneNumber ?? ''),
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ),

            const SizedBox(height: 24),

            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_digits, (i) => _box(i)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 12.5, color: Colors.red),
              ),
            ],

            const SizedBox(height: 20),

            if (!_canResend)
              Text(
                'يمكنك طلب رمز جديد بعد $_timeLabel',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade500),
              )
            else
              GestureDetector(
                onTap: _resend,
                child: const Text(
                  'إعادة إرسال الرمز',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: brandRed),
                ),
              ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_code.length < _digits || _verifying) ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_verifying ? 'جاري التحقق...' : 'تأكيد',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold)),
              ),
            ),

            if (_isEmail) ...[
              const SizedBox(height: 10),
              Text(
                'لم تجد الرسالة؟ تحقّق من مجلد البريد المزعج.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade500),
              ),
            ] else ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء',
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      // البريد ⇒ صفحة كاملة · الجوال ⇒ نافذة
      child: _isEmail
          ? Scaffold(
              backgroundColor: const Color(0xFFF7F8FA),
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: card,
                  ),
                ),
              ),
            )
          : Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: card,
            ),
    );
  }

  Widget _box(int index) {
    final filled = _controllers[index].text.isNotEmpty;
    final w = _digits > 4 ? 46.0 : 56.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _digits > 4 ? 4 : 6),
      child: SizedBox(
        width: w,
        height: 62,
        child: TextField(
          controller: _controllers[index],
          focusNode: _nodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: filled
                ? brandRed.withValues(alpha: 0.05)
                : const Color(0xFFF7F8FA),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: filled ? brandRed : const Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: brandRed, width: 1.6),
            ),
          ),
          onChanged: (v) => _onChanged(index, v),
        ),
      ),
    );
  }
}
