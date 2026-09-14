import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  const MerchantCheckoutPage({super.key, required this.plan});

  @override
  State<MerchantCheckoutPage> createState() => _MerchantCheckoutPageState();
}

class _MerchantCheckoutPageState extends State<MerchantCheckoutPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;
  final _codeCtrl = TextEditingController();

  bool _checking = false;
  double _discountPercent = 0;
  String? _appliedCode;
  String? _codeError;

  /// رصيد الترقية من الاشتراك الحالي
  bool _loadingProration = true;
  bool _hasCredit = false;
  double _credit = 0;
  double _newCost = 0;
  int _daysLeft = 0;

  /// مسار الحساب: new | free_upgrade | paid_upgrade | cycle_change
  String _mode = 'new';
  bool _keepExpiry = false;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _loadProration();
  }

  Future<void> _loadProration() async {
    try {
      final res = await supabase.rpc('calc_proration',
          params: {'p_new_plan_id': widget.plan['id']});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        setState(() {
          _mode = (map['mode'] ?? 'new').toString();
          _keepExpiry = map['keep_expiry'] == true;
          _credit = (map['credit'] as num?)?.toDouble() ?? 0;
          _newCost = (map['new_cost'] as num?)?.toDouble() ?? 0;
          _daysLeft = (map['days_left'] as num?)?.toInt() ?? 0;
          _hasCredit = _credit > 0;
        });
      }
    } catch (e) {
      debugPrint('Proration error: $e');
    } finally {
      if (mounted) setState(() => _loadingProration = false);
    }
  }

  double get _fullPrice =>
      (widget.plan['price'] as num?)?.toDouble() ?? 0;

  /// الأساس المحتسب: تكلفة الأيام المتبقية عند الترقية
  double get _basePrice => _hasCredit ? _newCost : _fullPrice;

  double get _discountValue => _basePrice * (_discountPercent / 100);

  double get _finalPrice {
    final afterDiscount = _basePrice - _discountValue;
    final due = _hasCredit ? afterDiscount - _credit : afterDiscount;
    return due < 0 ? 0 : due;
  }

  /// لا مستحقّ ⇒ لا حاجة لبوابة الدفع
  /// وحين تُرفع الأسعار في قاعدة البيانات يعود المسار للبوابة تلقائياً
  bool get _isFree => _finalPrice <= 0;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _checking) return;

    setState(() {
      _checking = true;
      _codeError = null;
    });

    try {
      final res = await supabase.rpc('check_promo_code', params: {
        'input_code': code,
        'input_plan_id': widget.plan['id'],
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['valid'] == true) {
        setState(() {
          _discountPercent = (map['percent'] as num).toDouble();
          _appliedCode = code.toUpperCase();
          _codeError = null;
        });
      } else {
        setState(() {
          _discountPercent = 0;
          _appliedCode = null;
          _codeError = map['error']?.toString() ?? 'الكود غير صالح';
        });
      }
    } catch (e) {
      setState(() {
        _discountPercent = 0;
        _appliedCode = null;
        _codeError = 'تعذر التحقق من الكود';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// يُنفَّذ بعد نجاح الدفع — جاهز للتفعيل عند ربط البوابة
  Future<void> _completePayment() async {
    if (_paying) return;
    setState(() => _paying = true);

    try {
      final res = await supabase.rpc('apply_upgrade', params: {
        'p_plan_id': widget.plan['id'],
        'p_paid': _finalPrice,
        'p_discount_percent': _discountPercent,
        'p_promo_code': _appliedCode,
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم تفعيل باقتك بنجاح',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(map['error']?.toString() ?? 'تعذر التفعيل',
              style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint('Apply upgrade error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر التفعيل، حاول مجدداً',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _removeCode() {
    setState(() {
      _codeCtrl.clear();
      _discountPercent = 0;
      _appliedCode = null;
      _codeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = (widget.plan['duration_days'] as num?)?.toInt() ?? 30;
    final name = (widget.plan['name'] ?? 'باقة').toString();

    if (_loadingProration) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: Center(child: CircularProgressIndicator(color: brandRed)),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== الترويسة =====
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18),
                        ),
                        const SizedBox(width: 4),
                        const Text('إتمام الاشتراك',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ===== ملخّص الباقة =====
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDEFF3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: brandRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.card_membership_rounded,
                                    color: brandRed,
                                    size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      days >= 365
                                          ? 'اشتراك سنوي'
                                          : 'اشتراك شهري',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFEDEFF3)),
                          const SizedBox(height: 14),

                          if (_mode == 'paid_upgrade') ...[
                            _row('سعر الباقة الكامل', _fullPrice,
                                color: Colors.grey),
                            const SizedBox(height: 10),
                            _row('تكلفة $_daysLeft يوماً متبقياً', _basePrice),
                          ] else
                            _row('سعر الباقة', _basePrice),

                          if (_discountPercent > 0) ...[
                            const SizedBox(height: 10),
                            _row(
                              'الخصم (${_discountPercent.toStringAsFixed(0)}%)',
                              -_discountValue,
                              color: Colors.green,
                            ),
                          ],

                          if (_hasCredit) ...[
                            const SizedBox(height: 10),
                            _row(
                                _mode == 'free_upgrade'
                                    ? 'خصم قيمة باقتك الحالية'
                                    : 'رصيدك من الباقة الحالية',
                                -_credit,
                                color: Colors.green),
                          ],

                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFFEDEFF3)),
                          const SizedBox(height: 14),

                          if (_hasCredit) ...[
                            Container(
                              padding: const EdgeInsets.all(11),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: Colors.green),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _mode == 'free_upgrade'
                                          ? 'تبدأ مدة اشتراك جديدة كاملة عند الترقية'
                                          : _mode == 'cycle_change'
                                              ? 'خُصم رصيد $_daysLeft يوماً من باقتك الحالية — وتبدأ مدة الباقة الجديدة كاملة من اليوم'
                                              : 'احتُسب رصيد $_daysLeft يوماً متبقياً — ويبقى تاريخ انتهائك كما هو',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11.5,
                                          height: 1.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          Row(
                            children: [
                              const Text('الإجمالي',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(
                                _isFree
                                    ? 'مجاني — فترة التأسيس'
                                    : '${_finalPrice.toStringAsFixed(2)} ر.س',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: _isFree ? 15 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: brandRed),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== كود الخصم =====
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDEFF3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('كود الخصم',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          if (_appliedCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.green
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'تم تطبيق $_appliedCode',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _removeCode,
                                    child: Text('إزالة',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: Colors.grey.shade600)),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _codeCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'أدخل الكود',
                                      hintStyle: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: Colors.grey.shade400),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F8FA),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                      errorText: _codeError,
                                      errorStyle: const TextStyle(
                                          fontFamily: 'Cairo', fontSize: 11),
                                    ),
                                    onSubmitted: (_) => _applyCode(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _checking ? null : _applyCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                      _checking ? '...' : 'تطبيق',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== الدفع =====
                    ElevatedButton.icon(
                      // مجاني ⇒ يعمل · بمقابل ⇒ ينتظر بوابة الدفع
                      onPressed:
                          (_isFree && !_paying) ? _completePayment : null,
                      icon: Icon(
                          _isFree
                              ? Icons.check_circle_outline_rounded
                              : Icons.lock_outline_rounded,
                          size: 18),
                      label: Text(_isFree ? 'تفعيل الباقة' : 'إتمام الدفع',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _isFree
                            ? 'فترة تأسيس مجانية — الاشتراكات ستبدأ لاحقاً '
                                'وستُبلَّغ قبلها بوقت كافٍ'
                            : 'بوابة الدفع قيد الربط — تواصل مع الإدارة '
                                'لتفعيل اشتراكك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade500),
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

  Widget _row(String label, double value, {Color? color}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: color ?? Colors.grey.shade700)),
        const Spacer(),
        Text(
          '${value.toStringAsFixed(2)} ر.س',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87),
        ),
      ],
    );
  }
}
