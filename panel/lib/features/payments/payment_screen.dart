// panel/lib/features/payments/payment_screen.dart
// شاشة الدفع: تطلب من الموقع (Next.js) إنشاء جلسة الدفع، ثم تنتقل لصفحة MyFatoorah.
// لا يوجد أي مفتاح سري هنا.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:red_market_core/red_market_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// عنوان الموقع الذي ينشئ جلسة الدفع
/// محلياً: http://localhost:3000 — عند النشر يُستبدل بنطاق الموقع
const String kPaymentsApiBase = 'http://localhost:3000';

class PaymentScreen extends StatefulWidget {
  final String? paymentType; // subscription | banner | splash_ad | custom
  final String? referenceId;
  final double? amount; // إذا مُرّر يُثبّت المبلغ ولا يُعدَّل

  const PaymentScreen({
    super.key,
    this.paymentType,
    this.referenceId,
    this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _border = Color(0xFFEDEFF3);
  static const _bg = Color(0xFFF7F8FA);
  static const _text = Color(0xFF1F2937);
  static const _muted = Color(0xFF757575);

  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.amount != null) {
      _amountController.text = widget.amount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// يقبل الأرقام العربية والهندية
  double get _amount {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var s = _amountController.text.trim();
    for (var i = 0; i < arabic.length; i++) {
      s = s.replaceAll(arabic[i], '$i');
    }
    s = s.replaceAll('٫', '.').replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  double _round2(double v) => (v * 100).roundToDouble() / 100;

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pay() async {
    final amount = _amount;
    if (amount <= 0) {
      _msg('أدخل مبلغاً صحيحاً');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _msg('يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$kPaymentsApiBase/api/payments/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'amount': amount,
          'payment_type': widget.paymentType ?? 'custom',
          'reference_id': widget.referenceId,
        }),
      );

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {}

      final url = body['payment_url']?.toString();
      if (res.statusCode != 200 || url == null || url.isEmpty) {
        _msg(body['error']?.toString() ?? 'تعذّر إنشاء الدفع (${res.statusCode})');
        return;
      }

      // نفس التبويب — لتجنّب حظر النوافذ المنبثقة في المتصفح
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (e) {
      _msg('تعذّر الاتصال بخادم الدفع');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 13.5),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: b(_border),
      enabledBorder: b(_border),
      disabledBorder: b(_border),
      focusedBorder: b(AppColors.brand, 1.4),
      suffixText: 'ر.س',
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? _text : _muted,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? _text,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _round2(_amount);
    final vat = _round2(base * 0.15);
    final total = _round2(base + vat);
    final fixed = widget.amount != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'إتمام الدفع',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'المبلغ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _text),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _amountController,
                      enabled: !fixed,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration('0.00'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _row('المبلغ الأساسي', '${base.toStringAsFixed(2)} ر.س'),
                  _row('ضريبة القيمة المضافة (15%)',
                      '${vat.toStringAsFixed(2)} ر.س'),
                  const Divider(height: 20, color: _border),
                  _row(
                    'الإجمالي',
                    '${total.toStringAsFixed(2)} ر.س',
                    bold: true,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _pay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        disabledBackgroundColor:
                            AppColors.brand.withAlpha(150),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'المتابعة إلى الدفع',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Color(0xFF4CAF50)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'الدفع يتم عبر صفحة MyFatoorah الآمنة',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
