import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantPromoPage extends StatefulWidget {
  const MerchantPromoPage({super.key});

  @override
  State<MerchantPromoPage> createState() => _MerchantPromoPageState();
}

class _MerchantPromoPageState extends State<MerchantPromoPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;

  int _followers = 0;
  int _limit = 0;
  int _used = 0;
  String _planType = '';

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _reels = [];
  List<Map<String, dynamic>> _sent = [];

  String _linkType = 'none'; // none | product | reel
  String? _linkedId;

  String get _uid => supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      final month = _monthKey();

      final profile = await supabase
          .from('profiles')
          .select('plan_id, promo_sends_month, promo_sends_count')
          .eq('id', _uid)
          .maybeSingle();

      String planType = '';
      if (profile?['plan_id'] != null) {
        final plan = await supabase
            .from('subscription_plans')
            .select('plan_type')
            .eq('id', profile!['plan_id'])
            .maybeSingle();
        planType = (plan?['plan_type'] ?? '').toString();
      }

      final followers = await supabase
          .from('merchant_followers')
          .select('id')
          .eq('merchant_id', _uid);

      final products = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', _uid)
          .eq('is_available', true)
          .order('created_at', ascending: false);

      final reels = await supabase
          .from('reels')
          .select('id, title')
          .eq('merchant_id', _uid)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final sent = await supabase
          .from('notifications_log')
          .select('title, body, created_at')
          .eq('target_type', 'followers')
          .eq('target_id', _uid)
          .eq('icon_type', 'promo')
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        _planType = planType;
        _limit = planType == 'pro' ? 3 : (planType == 'growth' ? 1 : 0);
        _used = (profile?['promo_sends_month'] == month)
            ? ((profile?['promo_sends_count'] as num?)?.toInt() ?? 0)
            : 0;
        _followers = (followers as List).length;
        _products = List<Map<String, dynamic>>.from(products);
        _reels = List<Map<String, dynamic>>.from(reels);
        _sent = List<Map<String, dynamic>>.from(sent);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Promo load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _monthKey() {
    final n = DateTime.now();
    return "${n.year}-${n.month.toString().padLeft(2, '0')}";
  }

  Future<void> _send() async {
    if (_sending) return;

    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      _snack("يرجى كتابة العنوان ونص الرسالة", Colors.red);
      return;
    }

    setState(() => _sending = true);

    try {
      final res = await supabase.rpc('send_promo_to_followers', params: {
        'p_title': _titleCtrl.text.trim(),
        'p_body': _bodyCtrl.text.trim(),
        'p_product_id': _linkType == 'product' ? _linkedId : null,
        'p_reel_id': _linkType == 'reel' ? _linkedId : null,
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        _snack(
          "وصلت رسالتك إلى ${map['followers']} متابع — متبقٍ ${map['remaining']} هذا الشهر",
          Colors.green,
        );
        _titleCtrl.clear();
        _bodyCtrl.clear();
        setState(() {
          _linkType = 'none';
          _linkedId = null;
        });
        await _load();
      } else {
        _snack(map['error']?.toString() ?? "تعذر الإرسال", Colors.red);
      }
    } catch (e) {
      _snack("تعذر الإرسال، حاول مجدداً", Colors.red);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: brandRed));
    }

    // الباقة الأساسية لا تملك هذه الميزة
    if (_limit == 0) {
      return _upgradePrompt();
    }

    final remaining = (_limit - _used).clamp(0, _limit);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== الملخّص =====
                Row(
                  children: [
                    Expanded(
                      child: _statTile("متابعوك", "$_followers",
                          Icons.group_rounded, Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statTile("متبقٍ هذا الشهر", "$remaining / $_limit",
                          Icons.send_rounded, brandRed),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ===== نموذج الرسالة =====
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
                      const Text("رسالة تسويقية لمتابعيك",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        "تصل باسم متجرك كإشعار في التطبيق والموقع",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 18),

                      _field(_titleCtrl, "العنوان",
                          "مثال: خصم 20% لمدة 24 ساعة"),
                      const SizedBox(height: 14),
                      _field(_bodyCtrl, "نص الرسالة",
                          "اكتب تفاصيل عرضك هنا", maxLines: 3),
                      const SizedBox(height: 18),

                      // ===== الربط =====
                      const Text("اربط الرسالة بـ",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _linkChip('none', 'بلا ربط'),
                          const SizedBox(width: 8),
                          _linkChip('product', 'عرض'),
                          const SizedBox(width: 8),
                          _linkChip('reel', 'ريلز'),
                        ],
                      ),

                      if (_linkType != 'none') ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _linkedId,
                          isExpanded: true,
                          style: const TextStyle(
                              fontFamily: 'Cairo', color: Colors.black87),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF7F8FA),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            hintText: _linkType == 'product'
                                ? "اختر عرضاً"
                                : "اختر ريلز",
                            hintStyle: const TextStyle(fontFamily: 'Cairo'),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: (_linkType == 'product' ? _products : _reels)
                              .map((e) => DropdownMenuItem<String>(
                                    value: e['id'].toString(),
                                    child: Text(
                                      (e['name'] ?? e['title'] ?? 'بلا عنوان')
                                          .toString(),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontFamily: 'Cairo', fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _linkedId = v),
                        ),
                      ],

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed:
                            (_sending || remaining == 0) ? null : _send,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _sending
                              ? "جاري الإرسال..."
                              : remaining == 0
                                  ? "استنفدت رسائل هذا الشهر"
                                  : "إرسال لمتابعيك",
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== السجل =====
                if (_sent.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text("الرسائل المرسلة",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 12),
                  ..._sent.map((m) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFEDEFF3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (m['title'] ?? '').toString(),
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                                Text(
                                  _fmtDate(m['created_at']),
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (m['body'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '';
    return "${d.year}/${d.month}/${d.day}";
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade400),
            filled: true,
            fillColor: const Color(0xFFF7F8FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _linkChip(String value, String label) {
    final on = _linkType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _linkType = value;
        _linkedId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: on ? brandRed : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
            color: on ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _upgradePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 18),
            const Text(
              "الرسائل التسويقية متاحة لباقتي النمو والاحترافية",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "رقّ باقتك لتصل عروضك إلى متابعيك مباشرة",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
