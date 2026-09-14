import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// صفحة الحملة الموسمية للتاجر
class MerchantCampaignPage extends StatefulWidget {
  const MerchantCampaignPage({super.key});

  @override
  State<MerchantCampaignPage> createState() => _MerchantCampaignPageState();
}

class _MerchantCampaignPageState extends State<MerchantCampaignPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _campaign;
  Map<String, dynamic>? _quota;
  List<Map<String, dynamic>> _myProducts = [];
  List<Map<String, dynamic>> _inCampaign = [];

  bool _loading = true;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      final camp = await supabase.rpc('get_active_campaign');

      if (camp == null) {
        if (mounted) {
          setState(() {
            _campaign = null;
            _loading = false;
          });
        }
        return;
      }

      final c = Map<String, dynamic>.from(camp as Map);
      final cid = c['id'].toString();

      Map<String, dynamic>? quota;
      List<Map<String, dynamic>> products = [];
      List<Map<String, dynamic>> inCamp = [];
      double balance = 0;

      if (uid != null) {
        final q = await supabase
            .from('campaign_quotas')
            .select()
            .eq('campaign_id', cid)
            .eq('merchant_id', uid)
            .maybeSingle();
        quota = q;

        final p = await supabase
            .from('products')
            .select('id, name, price, old_price, image_url')
            .eq('merchant_id', uid)
            .eq('is_available', true)
            .order('created_at', ascending: false)
            .limit(200);
        products = List<Map<String, dynamic>>.from(p);

        final s = await supabase
            .from('campaign_product_stats')
            .select()
            .eq('campaign_id', cid)
            .eq('merchant_id', uid);
        inCamp = List<Map<String, dynamic>>.from(s);

        final w = await supabase
            .from('merchant_wallets')
            .select('balance')
            .eq('merchant_id', uid)
            .maybeSingle();
        balance = ((w?['balance'] as num?) ?? 0).toDouble();
      }

      if (!mounted) return;
      setState(() {
        _campaign = c;
        _quota = quota;
        _myProducts = products;
        _inCampaign = inCamp;
        _balance = balance;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Campaign load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  int get _purchased =>
      (_quota?['quota_purchased'] as num?)?.toInt() ?? 0;

  int get _used => (_quota?['quota_used'] as num?)?.toInt() ?? 0;

  int get _remaining => _purchased - _used;

  /// هل العرض مضاف حالياً؟
  bool _isAdded(String productId) => _inCampaign.any((s) =>
      s['product_id'].toString() == productId &&
      s['current_status'] == 'active');

  /// إحصاءات عرض
  Map<String, dynamic>? _statsOf(String productId) {
    for (final s in _inCampaign) {
      if (s['product_id'].toString() == productId) return s;
    }
    return null;
  }

  // ===================== شراء الحصة =====================

  void _buyQuotaDialog() {
    int count = 5;
    bool busy = false;

    final fee = (_campaign?['entry_fee'] as num?)?.toDouble() ?? 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final subtotal = fee * count;
          final vat = subtotal * 0.15;
          final total = subtotal + vat;
          final enough = _balance >= total;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      color: brandRed, size: 19),
                  SizedBox(width: 10),
                  Text('شراء حصة عروض',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'كم عرضاً تريد إضافته للحملة؟',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey.shade700),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _stepBtn(Icons.remove_rounded, () {
                          if (count > 1) setModal(() => count--);
                        }),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 20),
                        _stepBtn(Icons.add_rounded, () {
                          if (count < 100) setModal(() => count++);
                        }),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Column(
                        children: [
                          _line('رسم العرض',
                              fee <= 0 ? 'مجاني' : '${fee.toInt()} ر.س'),
                          const SizedBox(height: 7),
                          _line('عدد العروض', '$count'),
                          const SizedBox(height: 7),
                          _line('ضريبة القيمة المضافة',
                              '${vat.toStringAsFixed(2)} ر.س'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 9),
                            child: Divider(
                                color: Color(0xFFE5E7EB), height: 1),
                          ),
                          Row(
                            children: [
                              const Text('الإجمالي',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(
                                  total <= 0
                                      ? 'مجاني — فترة التأسيس'
                                      : '${total.toStringAsFixed(2)} ر.س',
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: brandRed)),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Icon(
                                enough
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                size: 15,
                                color: enough ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 7),
                              Text('رصيدك',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600)),
                              const Spacer(),
                              Text('${_balance.toStringAsFixed(2)} ر.س',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: enough
                                          ? Colors.green
                                          : Colors.red)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء',
                      style: TextStyle(
                          fontFamily: 'Cairo', color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandRed,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (busy || !enough)
                      ? null
                      : () async {
                          setModal(() => busy = true);
                          try {
                            final res = await supabase
                                .rpc('purchase_campaign_quota', params: {
                              'p_campaign_id': _campaign!['id'],
                              'p_count': count,
                            });
                            final map =
                                Map<String, dynamic>.from(res as Map);

                            if (ctx.mounted) Navigator.pop(ctx);

                            if (map['ok'] == true) {
                              await _load();
                              _snack(
                                'اشتريت حصة $count عرض — '
                                'رصيدك ${(map['balance'] as num?)?.toStringAsFixed(2)} ر.س',
                                Colors.green,
                              );
                            } else {
                              _snack(
                                  map['error']?.toString() ?? 'تعذر الشراء',
                                  Colors.red);
                            }
                          } catch (e) {
                            debugPrint('Buy quota error: $e');
                            setModal(() => busy = false);
                            _snack('تعذر إتمام الشراء', Colors.red);
                          }
                        },
                  child: Text(
                      busy
                          ? 'جاري...'
                          : (enough ? 'تأكيد الشراء' : 'الرصيد غير كافٍ'),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 20, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ===================== إضافة وإزالة =====================

  Future<void> _toggleProduct(Map<String, dynamic> p) async {
    final pid = p['id'].toString();
    final added = _isAdded(pid);

    try {
      final fn = added
          ? 'remove_product_from_campaign'
          : 'add_product_to_campaign';

      final res = await supabase.rpc(fn, params: {
        'p_campaign_id': _campaign!['id'],
        'p_product_id': pid,
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack(added ? 'أُزيل من الحملة' : 'أُضيف للحملة',
            added ? Colors.orange : Colors.green);
      } else {
        if (map['need_quota'] == true) {
          _snack(map['error']?.toString() ?? 'نفدت حصتك', Colors.orange);
          _buyQuotaDialog();
        } else {
          _snack(map['error']?.toString() ?? 'تعذر التنفيذ', Colors.red);
        }
      }
    } catch (e) {
      debugPrint('Toggle product error: $e');
      _snack('تعذر تنفيذ العملية', Colors.red);
    }
  }

  // ===================== البناء =====================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: brandRed)),
                    )
                  : _campaign == null
                      ? _noCampaign()
                      : _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noCampaign() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined,
              size: 62, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('لا حملة نشطة حالياً',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا حين تُطلق الإدارة حملة موسمية',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final c = _campaign!;
    final daysLeft = (c['days_left'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== ترويسة الحملة =====
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [brandRed, Color(0xFF8E1010)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (c['title'] ?? '').toString(),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      daysLeft > 0 ? 'باقٍ $daysLeft يوم' : 'آخر يوم',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),

              if ((c['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  c['description'].toString(),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.9,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _headStat(
                        'عروضك في الحملة', '$_used'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _headStat('المتبقي من حصتك', '$_remaining'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _headStat('إجمالي عروض الحملة',
                        '${c['product_count'] ?? 0}'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ===== الحصة =====
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _remaining <= 0
                  ? Colors.orange.withValues(alpha: 0.4)
                  : const Color(0xFFEDEFF3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _purchased == 0
                    ? Icons.add_shopping_cart_rounded
                    : Icons.inventory_2_outlined,
                size: 20,
                color: _remaining <= 0 ? Colors.orange : brandRed,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _purchased == 0
                          ? 'لم تشترِ حصة بعد'
                          : 'حصتك $_used من $_purchased',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _purchased == 0
                          ? 'اشترِ حصة لتضيف عروضك للحملة'
                          : _remaining <= 0
                              ? 'نفدت حصتك — اشترِ المزيد أو أزل عرضاً'
                              : 'يمكنك إضافة $_remaining عرضاً بعد',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _buyQuotaDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                    _purchased == 0 ? 'شراء حصة' : 'زيادة الحصة',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        Text('عروضك',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'اضغط الزر لإضافة العرض للحملة أو إزالته',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: Colors.grey.shade500),
        ),

        const SizedBox(height: 14),

        if (_myProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('لا عروض متاحة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.grey.shade400)),
            ),
          )
        else
          ..._myProducts.map(_productRow),
      ],
    );
  }

  Widget _headStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _productRow(Map<String, dynamic> p) {
    final pid = p['id'].toString();
    final added = _isAdded(pid);
    final stats = _statsOf(pid);

    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final old = (p['old_price'] as num?)?.toDouble();
    final pct = (old != null && old > price && old > 0)
        ? (((old - price) / old) * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: added
              ? Colors.green.withValues(alpha: 0.4)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (p['image_url'] ?? '').toString().isNotEmpty
                ? Image.network(
                    p['image_url'],
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFF1F2F5),
                      child: const Icon(Icons.image_outlined,
                          size: 18, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFFF1F2F5),
                    child: const Icon(Icons.image_outlined,
                        size: 18, color: Colors.grey),
                  ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p['name'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                        price <= 0
                            ? 'مجاني'
                            : '${price.toStringAsFixed(0)} ر.س',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: brandRed)),
                    if (pct > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('-$pct%',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700)),
                      ),
                    ],
                    if (added && stats != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.visibility_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('${stats['views'] ?? 0}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade600)),
                      const SizedBox(width: 8),
                      Icon(Icons.touch_app_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('${stats['clicks'] ?? 0}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            height: 36,
            child: added
                ? OutlinedButton.icon(
                    onPressed: () => _toggleProduct(p),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text('في الحملة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(
                          color: Colors.green.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _toggleProduct(p),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('إضافة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandRed,
                      side: BorderSide(
                          color: brandRed.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
