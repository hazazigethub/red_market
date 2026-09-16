import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يُعرض مضمّناً داخل صفحة الاشتراكات
class MerchantInvoicesPage extends StatefulWidget {
  const MerchantInvoicesPage({super.key});

  @override
  State<MerchantInvoicesPage> createState() => _MerchantInvoicesPageState();
}

class _MerchantInvoicesPageState extends State<MerchantInvoicesPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final data = await supabase
          .from('merchant_subscriptions')
          .select()
          .eq('merchant_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Invoices load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return "${d.year}/${d.month}/${d.day}";
  }

  ({String label, Color color}) _statusInfo(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString();
    final isTrial = r['is_trial'] == true;

    if (isTrial) return (label: 'فترة تجريبية', color: Colors.blue);
    switch (status) {
      case 'active':
        return (label: 'نشط', color: Colors.green);
      case 'expired':
        return (label: 'منتهي', color: Colors.grey);
      case 'cancelled':
        return (label: 'ملغى', color: Colors.orange);
      default:
        return (label: status, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _pageShell(
      title: 'فواتير المتجر',
      icon: Icons.receipt_long_outlined,
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    if (_rows.isEmpty) return _empty();

    return Column(
      children: _rows.map(_invoiceCard).toList(),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> r) {
    final info = _statusInfo(r);
    final price = (r['price'] as num?)?.toDouble() ?? 0;
    final original = (r['original_price'] as num?)?.toDouble();
    final discount = (r['discount_percent'] as num?)?.toDouble() ?? 0;
    final promo = r['promo_code']?.toString();
    final billing = (r['billing'] ?? 'monthly').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                child: const Icon(Icons.receipt_long_rounded,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (r['plan_name'] ?? 'باقة').toString(),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      billing == 'yearly' ? 'اشتراك سنوي' : 'اشتراك شهري',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  info.label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: info.color),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 14),

          _line('تاريخ الإصدار', _fmt(r['created_at'])),
          const SizedBox(height: 8),
          _line('فترة الاشتراك',
              '${_fmt(r['started_at'])} — ${_fmt(r['expires_at'])}'),

          if (discount > 0) ...[
            const SizedBox(height: 8),
            _line(
              promo != null && promo.isNotEmpty
                  ? 'الخصم ($promo)'
                  : 'الخصم',
              '${discount.toStringAsFixed(0)}%',
              color: Colors.green,
            ),
          ],

          if (r['cancelled_at'] != null) ...[
            const SizedBox(height: 8),
            _line('تاريخ الإلغاء', _fmt(r['cancelled_at']),
                color: Colors.orange),
          ],

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              const Text('المبلغ',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (original != null && original > price) ...[
                Text(
                  '${original.toStringAsFixed(0)} ر.س',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                price == 0
                    ? 'مجاناً'
                    : '${price.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {Color? color}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87)),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا توجد فواتير بعد',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  /// إطار الصفحة — موحّد مع بقية اللوحة
  Widget _pageShell({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFF374151),
          shape: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: brandRed),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

}
