import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:red_market/core/services/campaign_service.dart';

/// صفحة الحملة الموسمية للعميل
class CampaignPage extends StatefulWidget {
  const CampaignPage({super.key});

  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage> {
  static const Color brandRed = Color(0xFFD32027);
  static const int _page = 24;

  final _service = CampaignService.instance;
  final _scroll = ScrollController();

  Map<String, dynamic>? _campaign;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];

  String? _category;
  double? _minDiscount;
  String _sort = 'random';

  bool _loading = true;
  bool _loadingMore = false;
  bool _done = false;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _init() async {
    final c = await _service.getActive();
    if (c == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final cats = await _service.getCategories(c['id'].toString());

    if (!mounted) return;
    setState(() {
      _campaign = c;
      _categories = cats;
    });

    await _loadProducts(reset: true);
  }

  Future<void> _loadProducts({required bool reset}) async {
    if (_campaign == null) return;

    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _done = false;
      });
    }

    final list = await _service.getProducts(
      campaignId: _campaign!['id'].toString(),
      categoryId: _category,
      minDiscount: _minDiscount,
      sort: _sort,
      limit: _page,
      offset: reset ? 0 : _offset,
    );

    if (!mounted) return;
    setState(() {
      _products = reset ? list : [..._products, ...list];
      _offset = (reset ? 0 : _offset) + list.length;
      _done = list.length < _page;
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _done || _loading) return;
    setState(() => _loadingMore = true);
    await _loadProducts(reset: false);
  }

  void _applyFilter() {
    _loadProducts(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            (_campaign?['title'] ?? 'الحملة الموسمية').toString(),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        ),
        body: _loading && _products.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: brandRed))
            : _campaign == null
                ? _noCampaign()
                : _content(),
      ),
    );
  }

  Widget _noCampaign() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_outlined,
              size: 62, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا حملة نشطة حالياً',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _content() {
    final c = _campaign!;
    final banner = (c['banner_image'] ?? '').toString();

    return RefreshIndicator(
      onRefresh: () => _loadProducts(reset: true),
      color: brandRed,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ===== البنر =====
          if (banner.isNotEmpty)
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 30 / 7,
                child: Image.network(
                  banner,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey.shade200),
                ),
              ),
            ),

          // ===== التصنيفات =====
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  children: [
                    _chip('الكل', _category == null, () {
                      setState(() => _category = null);
                      _applyFilter();
                    }),
                    ..._categories.map((cat) => _chip(
                          '${cat['name']} (${cat['product_count']})',
                          _category == cat['id'].toString(),
                          () {
                            setState(
                                () => _category = cat['id'].toString());
                            _applyFilter();
                          },
                        )),
                  ],
                ),
              ),
            ),

          // ===== الفلاتر =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _dropdown<double?>(
                      icon: Icons.percent_rounded,
                      value: _minDiscount,
                      hint: 'نسبة الخصم',
                      items: const [
                        (value: null, label: 'نسبة الخصم'),
                        (value: 20.0, label: 'خصم 20% فأكثر'),
                        (value: 30.0, label: 'خصم 30% فأكثر'),
                        (value: 50.0, label: 'خصم 50% فأكثر'),
                        (value: 75.0, label: 'خصم 75% فأكثر'),
                      ],
                      onChanged: (v) {
                        setState(() => _minDiscount = v);
                        _applyFilter();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown<String>(
                      icon: Icons.swap_vert_rounded,
                      value: _sort,
                      hint: 'ترتيب السعر',
                      items: const [
                        (value: 'random', label: 'ترتيب السعر'),
                        (value: 'price_asc', label: 'الأقل سعراً'),
                        (value: 'price_desc', label: 'الأعلى سعراً'),
                      ],
                      onChanged: (v) {
                        setState(() => _sort = v ?? 'random');
                        _applyFilter();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ===== الشبكة =====
          if (_products.isEmpty && !_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text('لا عروض مطابقة',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Colors.grey)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _productCard(_products[i]),
                  childCount: _products.length,
                ),
              ),
            ),

          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: brandRed)),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  /// قائمة منسدلة موحّدة
  Widget _dropdown<T>({
    required IconData icon,
    required T value,
    required String hint,
    required List<({T value, String label})> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                hint: Text(hint,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade500)),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Colors.grey.shade500),
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    color: Color(0xFF1F2937)),
                items: items
                    .map((e) => DropdownMenuItem<T>(
                          value: e.value,
                          child: Text(
                            e.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12.5),
                          ),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap,
      {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
              horizontal: small ? 13 : 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? brandRed : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? brandRed : const Color(0xFFEDEFF3)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: small ? 11.5 : 12.5,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final cid = _campaign!['id'].toString();

    final price = (p['discount_price'] as num?)?.toDouble() ??
        (p['price'] as num?)?.toDouble() ??
        0;
    final old = (p['old_price'] as num?)?.toDouble();
    final pct = (old != null && old > price && old > 0)
        ? (((old - price) / old) * 100).round()
        : 0;

    final img = (p['image_url'] ?? '').toString();

    return VisibilityDetector(
      key: Key('camp-$id'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.5) {
          _service.trackView(cid, id);
        }
      },
      child: GestureDetector(
        onTap: () {
          _service.trackClick(cid, id);
          context.push('/product-details/$id');
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: img.isNotEmpty
                          ? Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF1F2F5),
                                child: const Icon(Icons.image_outlined,
                                    color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFF1F2F5),
                              child: const Icon(Icons.image_outlined,
                                  color: Colors.grey),
                            ),
                    ),
                  ),
                  if (pct > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: brandRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('-$pct%',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['name'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 1.6),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${price.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: brandRed),
                        ),
                        if (pct > 0 && old != null) ...[
                          const SizedBox(width: 7),
                          Text(
                            old.toStringAsFixed(0),
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey.shade400),
                          ),
                        ],
                      ],
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
