import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market_core/red_market_core.dart';
import '../widgets/product_card.dart';

/// التصنيف الرئيسي + الفرعي + فرع الفرعي في شاشة واحدة
/// (نفس طريقة الموقع: شريطان أفقيان يُسحبان، والعروض تتفلتر بلا تنقّل)
class SubCategoriesScreen extends StatefulWidget {
  final String parentId;
  final String categoryName;

  const SubCategoriesScreen({
    super.key,
    required this.parentId,
    required this.categoryName,
  });

  @override
  State<SubCategoriesScreen> createState() => _SubCategoriesScreenState();
}

class _SubCategoriesScreenState extends State<SubCategoriesScreen> {
  static const Color brandRed = Color(0xFFD32027);
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _subs = [];
  List<Map<String, dynamic>> _leaves = [];
  List<ProductModel> _products = [];

  /// null = الكل
  String? _subId;
  String? _leafId;

  bool _loadingSubs = true;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final data = await supabase
          .from('product_categories')
          .select('id, name')
          .eq('parent_id', widget.parentId)
          .eq('is_visible', true)
          .order('sort_order', ascending: true).order('name', ascending: true);
      _subs = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Subs error: $e');
    }
    if (mounted) setState(() => _loadingSubs = false);
    await _loadProducts();
  }

  /// عروض الكل (كل الفرعيات) أو فرعي محدد
  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final ids = _subId != null
          ? [_subId!]
          : _subs.map((s) => s['id'].toString()).toList();

      if (ids.isEmpty) {
        _products = [];
      } else {
        final data = await supabase
            .from('products')
            .select('*')
            .inFilter('category_id', ids)
            .eq('is_available', true)
            .order('created_at', ascending: false)
            .limit(60);
        _products =
            (data as List).map((p) => ProductModel.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('Products error: $e');
      _products = [];
    }
    if (mounted) setState(() => _loadingProducts = false);
  }

  Future<void> _selectSub(String? id) async {
    if (_subId == id) return;
    setState(() {
      _subId = id;
      _leafId = null;
      _leaves = [];
    });

    if (id != null) {
      try {
        final data = await supabase
            .from('sup_product_subcategories')
            .select('id, name')
            .eq('parent_id', id)
            .eq('is_visible', true)
            .order('sort_order', ascending: true).order('name', ascending: true);
        if (mounted && _subId == id) {
          setState(() => _leaves = List<Map<String, dynamic>>.from(data));
        }
      } catch (e) {
        debugPrint('Leaves error: $e');
      }
    }
    await _loadProducts();
  }

  List<ProductModel> get _visible {
    if (_leafId == null) return _products;
    return _products.where((p) => p.subCategoryId == _leafId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.5,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.black, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text(
            widget.categoryName,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
        body: _loadingSubs
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : Column(
                children: [
                  const SizedBox(height: 12),

                  // ===== الفرعية =====
                  if (_subs.isNotEmpty)
                    _chipsRow(
                      height: 40,
                      items: _subs,
                      selected: _subId,
                      onTap: _selectSub,
                    ),

                  // ===== فرع الفرعية — يظهر عند اختيار فرعي =====
                  if (_subId != null && _leaves.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _chipsRow(
                      height: 34,
                      small: true,
                      items: _leaves,
                      selected: _leafId,
                      onTap: (id) => setState(() => _leafId = id),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Expanded(
                    child: _loadingProducts
                        ? const Center(
                            child: CircularProgressIndicator(color: brandRed))
                        : _visible.isEmpty
                            ? const Center(
                                child: Text("لا توجد عروض حالياً",
                                    style: TextStyle(fontFamily: 'Cairo')))
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: _visible.length,
                                itemBuilder: (context, index) =>
                                    ProductCard(product: _visible[index]),
                              ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chipsRow({
    required double height,
    required List<Map<String, dynamic>> items,
    required String? selected,
    required ValueChanged<String?> onTap,
    bool small = false,
  }) {
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('الكل', selected == null, () => onTap(null), small),
          for (final it in items) ...[
            const SizedBox(width: 8),
            _chip(
              (it['name'] ?? '').toString(),
              selected == it['id'].toString(),
              () => onTap(it['id'].toString()),
              small,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap, bool small) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on
              ? brandRed
              : Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? brandRed : brandRed.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: small ? 11.5 : 12.5,
            fontWeight: FontWeight.bold,
            color: on ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class SubCategoryItemsPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const SubCategoryItemsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<SubCategoryItemsPage> createState() => _SubCategoryItemsPageState();
}

class _SubCategoryItemsPageState extends State<SubCategoryItemsPage> {
  final supabase = Supabase.instance.client;
  List<ProductModel> _allProducts = [];
  List<Map<String, dynamic>> _subSubCategories = [];
  bool _isLoading = true;

  /// null يعني "الكل" — بلا فلترة
  String? _selectedSubSubId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        supabase
            .from('products')
            .select('*')
            .eq('category_id', widget.categoryId)
            .eq('is_available', true),
        supabase
            .from('sup_product_subcategories')
            .select()
            .eq('parent_id', widget.categoryId)
            .eq('is_visible', true)
            .order('sort_order', ascending: true).order('name', ascending: true),
      ]);

      if (mounted) {
        setState(() {
          _allProducts = (results[0] as List)
              .map((p) => ProductModel.fromJson(p))
              .toList();
          _subSubCategories = List<Map<String, dynamic>>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// العروض بعد تطبيق فلتر فرعي الفرعي — أو الكل
  List<ProductModel> get _filteredProducts {
    if (_selectedSubSubId == null) return _allProducts;
    return _allProducts
        .where((p) => p.subCategoryId == _selectedSubSubId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.5,
          title: Text(widget.categoryName,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.black, fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5)
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث في ${widget.categoryName}...',
                    hintStyle:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: brandRed),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            // شريط فرعي الفرعي — أفقي قابل للسحب، يظهر فقط إن وُجدت فروع
            if (_subSubCategories.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _subSubChip(label: "الكل", id: null),
                    const SizedBox(width: 8),
                    for (final s in _subSubCategories) ...[
                      _subSubChip(
                        label: (s['name'] ?? '').toString(),
                        id: s['id'].toString(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            if (_subSubCategories.isNotEmpty) const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: brandRed))
                  : _filteredProducts.isEmpty
                      ? const Center(
                          child: Text("لا توجد عروض حالياً",
                              style: TextStyle(fontFamily: 'Cairo')))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            return ProductCard(
                                product: _filteredProducts[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subSubChip({required String label, required String? id}) {
    const Color brandRed = Color(0xFFD32027);
    final bool selected = _selectedSubSubId == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedSubSubId = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? brandRed : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? brandRed : brandRed.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : brandRed,
          ),
        ),
      ),
    );
  }
}
