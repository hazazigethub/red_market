import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNewsletterScreen extends StatefulWidget {
  const AdminNewsletterScreen({super.key});

  @override
  State<AdminNewsletterScreen> createState() => _AdminNewsletterScreenState();
}

class _AdminNewsletterScreenState extends State<AdminNewsletterScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _busy = false;

  /// النوع المعروض: weekly | mega | hot
  String _kind = 'weekly';

  static const _kinds = <Map<String, String>>[
    {'key': 'weekly', 'label': 'الأسبوعية'},
    {'key': 'mega', 'label': 'تخفيضات 90%+'},
    {'key': 'hot', 'label': 'تخفيضات 70%+'},
  ];

  Map<String, dynamic>? _draft;
  List<Map<String, dynamic>> _draftItems = [];
  List<Map<String, dynamic>> _history = [];
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // توليد تلقائي حسب النوع
      final gen = _kind == 'weekly'
          ? await supabase.rpc('generate_weekly_newsletter')
          : await supabase.rpc('generate_discount_newsletter',
              params: {'p_kind': _kind});

      final genMap = Map<String, dynamic>.from(gen as Map);
      _note = genMap['created'] == true
          ? null
          : genMap['reason']?.toString();

      final drafts = await supabase
          .from('newsletters')
          .select('id, title, created_at, status')
          .eq('status', 'draft')
          .eq('kind', _kind)
          .order('created_at', ascending: false)
          .limit(1);

      final draftList = List<Map<String, dynamic>>.from(drafts);
      _draft = draftList.isEmpty ? null : draftList.first;

      if (_draft != null) {
        final items = await supabase
            .from('newsletter_items')
            .select('position, product_id, merchant_id')
            .eq('newsletter_id', _draft!['id'])
            .order('position');

        final ids = List<Map<String, dynamic>>.from(items)
            .map((e) => e['product_id'].toString())
            .toList();

        if (ids.isNotEmpty) {
          final products = await supabase
              .from('products')
              .select('id, name, price, old_price, image_url, store_name')
              .inFilter('id', ids);
          _draftItems = List<Map<String, dynamic>>.from(products);
        } else {
          _draftItems = [];
        }
      } else {
        _draftItems = [];
      }

      final hist = await supabase
          .from('newsletters')
          .select('id, title, sent_at, status')
          .eq('status', 'sent')
          .eq('kind', _kind)
          .order('sent_at', ascending: false)
          .limit(10);
      _history = List<Map<String, dynamic>>.from(hist);
    } catch (e) {
      debugPrint('Newsletter load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve() async {
    if (_draft == null || _busy) return;
    setState(() => _busy = true);

    try {
      final res = await supabase
          .rpc('approve_newsletter', params: {'p_id': _draft!['id']});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        _snack("تم اعتماد النشرة وإرسالها للعملاء", Colors.green);
        await _load();
      } else {
        _snack(map['error']?.toString() ?? "تعذر الاعتماد", Colors.red);
      }
    } catch (e) {
      _snack("تعذر الاعتماد، حاول مجدداً", Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeItem(String productId) async {
    if (_draft == null) return;
    try {
      await supabase
          .from('newsletter_items')
          .delete()
          .eq('newsletter_id', _draft!['id'])
          .eq('product_id', productId);
      setState(() =>
          _draftItems.removeWhere((p) => p['id'].toString() == productId));
    } catch (e) {
      debugPrint('Remove item error: $e');
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '';
    return "${d.year}/${d.month}/${d.day}";
  }

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
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tabs(),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_draft == null)
                    _emptyState()
                  else
                    _draftCard(),
                  if (!_loading && _history.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text("النشرات المرسلة",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._history.map((n) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFEDEFF3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_read_rounded,
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    (n['title'] ?? 'نشرة').toString(),
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Text(_fmt(n['sent_at']),
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    return Wrap(
      spacing: 10,
      children: _kinds.map((k) {
        final on = _kind == k['key'];
        return GestureDetector(
          onTap: () {
            if (_kind == k['key']) return;
            setState(() => _kind = k['key']!);
            _load();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: on ? brandRed : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: on ? brandRed : const Color(0xFFEDEFF3)),
            ),
            child: Text(
              k['label']!,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        children: [
          Icon(Icons.mail_outline_rounded,
              size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد نشرة بانتظار الاعتماد",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  Widget _draftCard() {
    return Container(
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: brandRed, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((_draft!['title'] ?? 'نشرة').toString(),
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text("${_draftItems.length} عرضاً · ${_fmt(_draft!['created_at'])}",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _busy ? null : _approve,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_busy ? "جاري الاعتماد..." : "اعتماد وإرسال",
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          GridView.extent(
            maxCrossAxisExtent: 190,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
            children: _draftItems.map((p) => _itemCard(p)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> p) {
    final img = (p['image_url'] ?? '').toString();
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final oldP = (p['old_price'] as num?)?.toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFFF7F8FA),
                  child: img.isEmpty
                      ? const Icon(Icons.image_not_supported,
                          color: Colors.grey)
                      : Image.network(img, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey)),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: GestureDetector(
                    onTap: () => _removeItem(p['id'].toString()),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: brandRed),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((p['store_name'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9,
                          color: Colors.grey)),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text((p['name'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            height: 1.4)),
                  ),
                  Row(
                    children: [
                      if (oldP != null && oldP > price) ...[
                        Text(oldP.toStringAsFixed(0),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            )),
                        const SizedBox(width: 5),
                      ],
                      Text(price.toStringAsFixed(0),
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: brandRed)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
