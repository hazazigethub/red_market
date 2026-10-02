import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ إضافة Riverpod
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantBankAccountPage extends ConsumerStatefulWidget {
  const MerchantBankAccountPage({super.key});

  @override
  ConsumerState<MerchantBankAccountPage> createState() =>
      _MerchantBankAccountPageState();
}

class _MerchantBankAccountPageState
    extends ConsumerState<MerchantBankAccountPage> {
  static const Color brandRed = Color(0xFFD32027);

  final _formKey = GlobalKey<FormState>();

  // وحدات التحكم في النصوص
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  bool _isLinked = false;

  final supabase = Supabase.instance.client;

  double _balance = 0;
  double _totalCharged = 0;
  double _totalSpent = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _loadingWallet = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  /// يجلب الرصيد وسجل الحركات
  Future<void> _loadWallet() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final wallet = await supabase
          .from('merchant_wallets')
          .select()
          .eq('merchant_id', uid)
          .maybeSingle();

      final tx = await supabase
          .from('wallet_transactions')
          .select()
          .eq('merchant_id', uid)
          .order('created_at', ascending: false)
          .limit(30);

      if (!mounted) return;

      setState(() {
        _balance = ((wallet?['balance'] as num?) ?? 0).toDouble();
        _totalCharged = ((wallet?['total_charged'] as num?) ?? 0).toDouble();
        _totalSpent = ((wallet?['total_spent'] as num?) ?? 0).toDouble();
        _transactions = List<Map<String, dynamic>>.from(tx);
        _loadingWallet = false;
      });
    } catch (e) {
      debugPrint('Wallet load error: $e');
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  /// طرق الدفع المعتمدة في المنصة
  static const _paymentMethods = <Map<String, dynamic>>[
    {'label': 'مدى', 'icon': Icons.credit_card_rounded},
    {'label': 'فيزا', 'icon': Icons.payment_rounded},
    {'label': 'ماستركارد', 'icon': Icons.credit_score_rounded},
    {'label': 'Apple Pay', 'icon': Icons.phone_iphone_rounded},
  ];

  void _linkAccount() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLinked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تم ربط وتوثيق الحساب البنكي بنجاح ✅",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: brandRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 900;
                  final balance = _buildBalanceCard(isDark);
                  final history = _buildHistory(isDark);
                  final card = _buildStatusCard(isDark);
                  final form = _buildBankForm(isDark);
                  final methods = _buildPaymentMethods(isDark);

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        balance,
                        const SizedBox(height: 16),
                        history,
                        const SizedBox(height: 28),
                        card,
                        const SizedBox(height: 16),
                        methods,
                        const SizedBox(height: 28),
                        form,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: balance),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: history),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                card,
                                const SizedBox(height: 16),
                                methods,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: form),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== بطاقة الرصيد =====================

  Widget _buildBalanceCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandRed, Color(0xFF8E1010)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandRed.withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text(
                "رصيد المتجر",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_loadingWallet)
            const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _balance.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    "ر.س",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 6),

          const Text(
            "يُستخدم الرصيد في شراء المساحات الإعلانية",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.8,
              fontFamily: 'Cairo',
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _statBox('شُحن', _totalCharged),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox('صُرف', _totalSpent),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              // لتفعيل الشحن: استبدل null بـ _openChargeSheet
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded, size: 17),
              label: const Text(
                "شحن الرصيد",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: brandRed,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.25),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              "بوابة الدفع قيد الربط — تواصل مع الإدارة لشحن رصيدك",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${value.toStringAsFixed(0)} ر.س',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  // ===================== سجل الحركات =====================

  Widget _buildHistory(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 18, color: brandRed),
              const SizedBox(width: 10),
              Text(
                "سجل الحركات",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_loadingWallet)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                  child: CircularProgressIndicator(color: brandRed)),
            )
          else if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 44, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    "لا حركات بعد",
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Cairo',
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._transactions.map((t) => _txRow(t, isDark)),
        ],
      ),
    );
  }

  Widget _txRow(Map<String, dynamic> t, bool isDark) {
    final type = (t['type'] ?? '').toString();
    final amount = ((t['amount'] as num?) ?? 0).toDouble();
    final positive = amount >= 0;

    final (IconData icon, Color color) = switch (type) {
      'charge' => (Icons.add_circle_outline_rounded, Colors.green),
      'purchase' => (Icons.shopping_bag_outlined, brandRed),
      'refund' => (Icons.undo_rounded, Colors.blue),
      _ => (Icons.swap_horiz_rounded, Colors.grey),
    };

    final d = DateTime.tryParse((t['created_at'] ?? '').toString())?.toLocal();
    final date = d == null ? '' : '${d.year}/${d.month}/${d.day}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (t['description'] ?? '—').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'Cairo',
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: positive ? Colors.green.shade700 : brandRed,
            ),
          ),
        ],
      ),
    );
  }

  // بطاقة عرض الرصيد وحالة الحساب المحسنة
  Widget _buildStatusCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLinked
              ? [brandRed, const Color(0xFF8E1010)]
              : (isDark
                    ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                    : [const Color(0xFF3A3F47), const Color(0xFF23272D)]),
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isLinked ? brandRed : Colors.black).withValues(
              alpha: isDark ? 0.25 : 0.12,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "الحساب البنكي",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _isLinked
                ? "حسابك البنكي مربوط ومعتمد لدى المنصة."
                : "أضف بيانات حسابك البنكي لاعتماده لدى المنصة.",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.9,
              fontFamily: 'Cairo',
            ),
          ),
          if (_isLinked) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ownerNameController.text.isEmpty
                        ? "—"
                        : _ownerNameController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _ibanController.text.isEmpty
                        ? "—"
                        : _maskIban(_ibanController.text),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// طرق الدفع المعتمدة — عرض تعريفي
  Widget _buildPaymentMethods(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 11),
              Text(
                "طرق الدفع المعتمدة",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _paymentMethods.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : const Color(0xFFEDEFF3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m['icon'] as IconData,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      m['label'] as String,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF4A5468),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: brandRed.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: brandRed),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "تُسدَّد رسوم الاشتراك عبر هذه الوسائل، ويُعاد أي استرداد "
                    "إلى الوسيلة نفسها.",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      height: 1.7,
                      color: isDark
                          ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// يُخفي وسط الآيبان ويُبقي أوله وآخره
  String _maskIban(String iban) {
    final v = iban.trim().toUpperCase();
    if (v.length < 8) return v;
    return "${v.substring(0, 4)} •••• ${v.substring(v.length - 4)}";
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _isLinked
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLinked ? Colors.white30 : Colors.amber.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isLinked ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: _isLinked ? Colors.white : Colors.amber,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isLinked ? "حساب موثق" : "يتطلب ربط",
            style: TextStyle(
              color: _isLinked ? Colors.white : Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  // نموذج إدخال البيانات البنكية المطور
  Widget _buildBankForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: brandRed, size: 20),
              const SizedBox(width: 10),
              Text(
                "بيانات التحويل البنكي",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _buildLabel("اسم صاحب الحساب (المستفيد)", isDark),
          TextFormField(
            controller: _ownerNameController,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              "الاسم الكامل كما يظهر في بطاقة البنك",
              Icons.person_outline_rounded,
              isDark,
            ),
            validator: (val) => val!.isEmpty ? "يرجى إدخال اسم المستفيد" : null,
          ),
          const SizedBox(height: 20),
          _buildLabel("رقم الآيبان (IBAN)", isDark),
          TextFormField(
            controller: _ibanController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(24),
            ],
            decoration:
                _inputDecoration(
                  "SA00 0000 0000...",
                  Icons.fingerprint_rounded,
                  isDark,
                ).copyWith(
                  helperText: "تنسيق صحيح: يبدأ بـ SA متبوعاً بـ 22 رقماً",
                  helperStyle: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
            validator: (val) {
              if (val!.isEmpty) return "يرجى إدخال الآيبان";
              if (!val.toUpperCase().startsWith("SA") || val.length != 24) {
                return "تنسيق الآيبان غير صحيح (24 خانة)";
              }
              return null;
            },
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _linkAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "حفظ وتأكيد البيانات البنكية",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: Text(
              "تتم معالجة كافة البيانات المالية عبر أنظمة مشفرة وآمنة",
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Cairo',
                color: isDark ? Colors.white24 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 5),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : Colors.black54,
        fontFamily: 'Cairo',
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : Colors.grey,
        fontSize: 13,
        fontFamily: 'Cairo',
      ),
      prefixIcon: Icon(icon, color: brandRed, size: 22),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brandRed, width: 1.5),
      ),
      errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
    );
  }
}
