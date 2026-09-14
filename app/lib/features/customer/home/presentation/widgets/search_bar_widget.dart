import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/features/customer/home/presentation/pages/sub_categories_screen.dart';
import 'package:red_market_core/red_market_core.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic> _activeFilter = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: const Color(0xFFD32027).withValues(alpha: 0.5),
                  width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: "ابحث عن عرضك...",
                hintStyle: const TextStyle(
                    color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFFD32027), size: 24),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.grey, size: 20),
                        onPressed: () => setState(() => _controller.clear()),
                      )
                    : _FilterButton(
                        onFilterApplied: (filter) {
                          setState(() => _activeFilter = filter);
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: _SearchResultsDropdown(
                query: _controller.text,
                activeFilter: _activeFilter,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatefulWidget {
  final Function(Map<String, dynamic>) onFilterApplied;
  const _FilterButton({required this.onFilterApplied});

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  String? _selectedDateSort;
  String? _selectedPriceSort;
  final TextEditingController _minPrice = TextEditingController();
  final TextEditingController _maxPrice = TextEditingController();

  final List<Map<String, String>> _sortRow1 = [
    {'label': 'الأحدث', 'value': 'newest'},
    {'label': 'الأقدم', 'value': 'oldest'},
  ];

  final List<Map<String, String>> _sortRow2 = [
    {'label': 'السعر (الأعلى)', 'value': 'price_high'},
    {'label': 'السعر (الأقل)', 'value': 'price_low'},
  ];

  @override
  void dispose() {
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  bool get _hasFilter =>
      _selectedDateSort != null ||
      _selectedPriceSort != null ||
      _minPrice.text.isNotEmpty ||
      _maxPrice.text.isNotEmpty;

  Widget _buildSortOption(
      Map<String, String> option, StateSetter setSheetState, String type) {
    final bool isSelected = type == 'date'
        ? _selectedDateSort == option['value']
        : _selectedPriceSort == option['value'];

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (type == 'date') {
            final newVal =
                _selectedDateSort == option['value'] ? null : option['value'];
            setSheetState(() => _selectedDateSort = newVal);
            setState(() => _selectedDateSort = newVal);
          } else {
            final newVal =
                _selectedPriceSort == option['value'] ? null : option['value'];
            setSheetState(() => _selectedPriceSort = newVal);
            setState(() => _selectedPriceSort = newVal);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD32027) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFFD32027) : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            option['label']!,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
              border: const Border(
                top: BorderSide(color: Color(0xFFD32027), width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("تصفية النتائج",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 16),
                const Text("الترتيب",
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSortOption(_sortRow1[0], setSheetState, 'date'),
                    const SizedBox(width: 8),
                    _buildSortOption(_sortRow1[1], setSheetState, 'date'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSortOption(_sortRow2[0], setSheetState, 'price'),
                    const SizedBox(width: 8),
                    _buildSortOption(_sortRow2[1], setSheetState, 'price'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("نطاق السعر",
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPrice,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "من",
                          hintStyle: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.grey,
                              fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFD32027)),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("—",
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxPrice,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "إلى",
                          hintStyle: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.grey,
                              fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFD32027)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            _selectedDateSort = null;
                            _selectedPriceSort = null;
                          });
                          setState(() {
                            _selectedDateSort = null;
                            _selectedPriceSort = null;
                            _minPrice.clear();
                            _maxPrice.clear();
                          });
                          widget.onFilterApplied({});
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("مسح الكل",
                            style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onFilterApplied({
                            'dateSort': _selectedDateSort,
                            'priceSort': _selectedPriceSort,
                            'minPrice': _minPrice.text,
                            'maxPrice': _maxPrice.text,
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32027),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("تطبيق",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded,
              color: Color(0xFFD32027), size: 20),
          onPressed: _showFilterSheet,
        ),
        if (_hasFilter)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFD32027),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultsDropdown extends StatefulWidget {
  final String query;
  final Map<String, dynamic> activeFilter;

  const _SearchResultsDropdown({
    required this.query,
    required this.activeFilter,
  });

  @override
  State<_SearchResultsDropdown> createState() => _SearchResultsDropdownState();
}

class _SearchResultsDropdownState extends State<_SearchResultsDropdown> {
  late Future<List<dynamic>> _future;

  String get query => widget.query;
  Map<String, dynamic> get activeFilter => widget.activeFilter;

  @override
  void initState() {
    super.initState();
    _future = _fetchResults();
  }

  @override
  void didUpdateWidget(covariant _SearchResultsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.activeFilter != widget.activeFilter) {
      _future = _fetchResults();
    }
  }

  Future<List<dynamic>> _fetchResults() async {
    final minPrice = double.tryParse(activeFilter['minPrice'] ?? '');
    final maxPrice = double.tryParse(activeFilter['maxPrice'] ?? '');
    final String? dateSort = activeFilter['dateSort'];
    final String? priceSort = activeFilter['priceSort'];

    var q = Supabase.instance.client
        .from('products')
        .select('*, merchants(store_name)')
        .ilike('name', '%$query%')
        .eq('is_available', true)
        .or('is_banned.eq.false,is_banned.is.null');

    if (minPrice != null) q = q.gte('price', minPrice);
    if (maxPrice != null) q = q.lte('price', maxPrice);

    if (priceSort != null && dateSort != null) {
      return await q
          .order('price', ascending: priceSort == 'price_low')
          .order('created_at', ascending: dateSort == 'oldest')
          .limit(5);
    } else if (priceSort != null) {
      return await q
          .order('price', ascending: priceSort == 'price_low')
          .limit(5);
    } else if (dateSort != null) {
      return await q
          .order('created_at', ascending: dateSort == 'oldest')
          .limit(5);
    } else {
      return await q.order('created_at', ascending: false).limit(5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(
              minHeight: 2, color: Color(0xFFD32027));
        }
        final results = snapshot.data ?? const [];

        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: results.isNotEmpty
              ? Column(
                  children: results
                      .map((data) =>
                          _ProductTile(product: ProductModel.fromJson(data)))
                      .toList(),
                )
              : _NoResultsSuggestions(query: query),
        );
      },
    );
  }
}

class _NoResultsSuggestions extends StatefulWidget {
  final String query;
  const _NoResultsSuggestions({required this.query});

  @override
  State<_NoResultsSuggestions> createState() => _NoResultsSuggestionsState();
}

class _NoResultsSuggestionsState extends State<_NoResultsSuggestions> {
  late Future<Map<String, dynamic>> _future;

  String get query => widget.query;

  @override
  void initState() {
    super.initState();
    _future = _fetchSuggestions();
  }

  @override
  void didUpdateWidget(covariant _NoResultsSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _future = _fetchSuggestions();
    }
  }

  Future<Map<String, dynamic>> _fetchSuggestions() async {
    final categories = await Supabase.instance.client
        .from('product_categories')
        .select('id, name')
        .ilike('name', '%$query%')
        .limit(3);

    final mainCategories = await Supabase.instance.client
        .from('store_categories')
        .select('id, name')
        .ilike('name', '%$query%')
        .limit(3);

    final allCategories = [
      ...(categories as List).map((c) => {...c, 'type': 'sub'}),
      ...(mainCategories as List).map((c) => {...c, 'type': 'main'}),
    ];

    List<dynamic> relatedProducts = [];

    if (allCategories.isNotEmpty) {
      final categoryIds = allCategories.map((c) => c['id'].toString()).toList();

      final products = await Supabase.instance.client
          .from('products')
          .select()
          .filter('category_id', 'in', categoryIds)
          .eq('is_available', true)
          .or('is_banned.eq.false,is_banned.is.null')
          .order('created_at', ascending: false)
          .limit(10);

      final list = products as List;
      list.shuffle();
      relatedProducts = list.take(3).toList();
    }

    return {
      'categories': allCategories,
      'products': relatedProducts,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox();
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFD32027), strokeWidth: 2)),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final List categories = (data['categories'] as List?) ?? const [];
        final List products = (data['products'] as List?) ?? const [];

        // ✅ إذا ما فيه تصنيفات ولا عروض — لا تعرض شيء
        if (categories.isEmpty && products.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("لم نجد نتائج مطابقة",
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("لم نجد نتائج دقيقة، هل تقصد؟",
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),

              // ✅ التصنيفات المتعلقة بالبحث فقط
              if (categories.isNotEmpty) ...[
                const Text("الأقسام المتعلقة:",
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: categories
                      .map((cat) => ActionChip(
                            avatar: const Icon(Icons.category_rounded,
                                size: 16, color: Color(0xFFD32027)),
                            label: Text(cat['name'] ?? '',
                                style: const TextStyle(
                                    fontFamily: 'Cairo', fontSize: 12)),
                            onPressed: () {
                              final bool isMain = cat['type'] == 'main';
                              if (isMain) {
                                // ✅ تصنيف رئيسي — اذهب لصفحة التصنيفات الفرعية
                                context.push(
                                  RoutePaths.subCategories,
                                  extra: {
                                    'parentId': cat['id'].toString(),
                                    'categoryName': cat['name'] ?? '',
                                  },
                                );
                              } else {
                                // ✅ تصنيف فرعي — اذهب مباشرة للعروض
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubCategoryItemsPage(
                                      categoryId: cat['id'].toString(),
                                      categoryName: cat['name'] ?? '',
                                    ),
                                  ),
                                );
                              }
                            },
                          ))
                      .toList(),
                ),

                // ✅ عروض من نفس التصنيف فقط — بدون fallback
                if (products.isNotEmpty) ...[
                  if (categories.isNotEmpty) const Divider(),
                  const Text("عروض قد تنال إعجابك:",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Column(
                    children: products
                        .map((data) =>
                            _ProductTile(product: ProductModel.fromJson(data)))
                        .toList(),
                  ),
                ],
              ]
            ],
          ),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(product.imageUrl ?? "",
            width: 40, height: 40, fit: BoxFit.cover),
      ),
      title: Text(product.name,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      subtitle: PriceWidget(
        price: product.price,
        fontSize: 12,
      ),
      onTap: () => context.push(RoutePaths.productDetails, extra: product),
    );
  }
}
