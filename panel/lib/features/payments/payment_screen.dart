// panel/lib/features/payments/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:red_market_core/services/payment/myratoorah_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String? paymentType; // subscription | banner | splash_ad
  final String? referenceId;

  const PaymentScreen({super.key, this.paymentType, this.referenceId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late double _amount;
  late String _description;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amount = 0;
    _description = _getDefaultDescription();
    _loadAmount();
  }

  String _getDefaultDescription() {
    switch (widget.paymentType) {
      case 'subscription':
        return 'رسوم اشتراك العضوية';
      case 'banner':
        return 'رسوم حجز البنر الإعلاني';
      case 'splash_ad':
        return 'رسوم الإعلان على الشاشة الرئيسية';
      default:
        return 'رسوم الخدمة';
    }
  }

  Future<void> _loadAmount() async {
    // اجلب المبلغ من البيانات المرتبطة
    final supabase = Supabase.instance.client;

    try {
      if (widget.paymentType == 'subscription' && widget.referenceId != null) {
        final data = await supabase
            .from('subscription_plans')
            .select('price')
            .eq('id', widget.referenceId ?? '')
            .maybeSingle();

        if (data != null) {
          setState(() => _amount = (data['price'] as num).toDouble());
        }
      } else if (widget.paymentType == 'banner' && widget.referenceId != null) {
        final data = await supabase
            .from('banner_bookings')
            .select('final_price')
            .eq('id', widget.referenceId ?? '')
            .maybeSingle();

        if (data != null) {
          setState(() => _amount = (data['final_price'] as num).toDouble());
        }
      }
    } catch (e) {
      debugPrint('خطأ تحميل المبلغ: $e');
    }
  }

  Future<void> _initiatePayment() async {
    if (_amount <= 0) {
      _showSnackBar('⚠️ يجب إدخال مبلغ صحيح', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        _showSnackBar('❌ يجب تسجيل الدخول أولاً', Colors.red);
        return;
      }

      // احصل على معرّف التاجر
      final profileData = await supabase
          .from('profiles')
          .select('id')
          .eq('id', currentUser.id)
          .maybeSingle();

      final merchantId = profileData?['id'] ?? currentUser.id;

      // احسب VAT
      final vat = _amount * 0.15;
      final total = _amount + vat;

      // أنشئ سجل الدفعة
      final paymentResponse = await supabase
          .from('payments')
          .insert({
            'merchant_id': merchantId,
            'amount': _amount,
            'vat_amount': vat,
            'total_amount': total,
            'payment_type': widget.paymentType ?? 'custom',
            'reference_id': widget.referenceId,
            'status': 'pending',
          })
          .select()
          .single();

      final paymentId = paymentResponse['id'];

      // أنشئ جلسة دفع مع Myratoorah
      final myratoorah = MyratoorahService(
        apiKey:
            'SK_SAU_o0dX0F2pBUQ0BZhfA9dD0JZ5y3DOIvKJ4Khwfln0knYBy3I8dBcw2Pk5FqTB3vw6',
      );

      final returnUrl =
          'https://redmarket.panel.com/payments/callback?id=$paymentId';
      const webhookUrl = 'https://redmarket.api.com/webhooks/payment';

      final session = await myratoorah.createPaymentSession(
        orderId: paymentId,
        amount: total,
        merchantReference: paymentId,
        returnUrl: returnUrl,
        webhookUrl: webhookUrl,
        description: _description,
      );

      if (session != null) {
        // حدّث معرّف الجلسة
        await supabase
            .from('payments')
            .update({
              'myratoorah_session_id': session.sessionId,
              'myratoorah_payment_id': session.sessionId,
              'status': 'processing',
            })
            .eq('id', paymentId);

        // افتح صفحة الدفع
        if (await canLaunchUrl(Uri.parse(session.paymentUrl))) {
          await launchUrl(
            Uri.parse(session.paymentUrl),
            mode: LaunchMode.externalApplication,
          );
        }

        _showSnackBar('✅ تم فتح صفحة الدفع', Colors.green);
      } else {
        _showSnackBar('❌ فشل إنشاء جلسة الدفع', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      _showSnackBar('❌ حدث خطأ: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vat = _amount * 0.15;
    final total = _amount + vat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الدفع'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ========== بطاقة تفاصيل الدفع ==========
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFEDEFF3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'تفاصيل الدفع',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // المبلغ الأساسي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_amount.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          const Text(
                            'المبلغ الأساسي:',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ضريبة القيمة المضافة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${vat.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          const Text(
                            'ضريبة القيمة المضافة (15%):',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Divider(height: 1, color: Colors.grey[300]),
                      const SizedBox(height: 12),

                      // الإجمالي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${total.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const Text(
                            'الإجمالي:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ========== حقل الوصف ==========
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'وصف الدفع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _description,
                    onChanged: (value) => setState(() => _description = value),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'ادخل وصف الدفع',
                      hintStyle: const TextStyle(fontFamily: 'Cairo'),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFEDEFF3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFEDEFF3)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ========== زر الدفع ==========
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _initiatePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'المتابعة إلى الدفع',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Cairo',
                          ),
                        ),
                ),
              ),

              // ملاحظة أمان
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.lock, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'عملية الدفع آمنة وموثوقة. بيانات بطاقتك محمية بمعايير الأمان العالمية',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                          fontFamily: 'Cairo',
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
    );
  }
}
