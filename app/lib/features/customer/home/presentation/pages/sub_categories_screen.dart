import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market_core/red_market_core.dart';
import '../widgets/product_card.dart';

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
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

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
        body: FutureBuilder<List<Map<String, dynamic>>>(
          // ✅ نجلب اسم التصنيف الرئيسي مع كل تصنيف فرعي
          future: supabase
              .from('product_categories')
              .select('*, parent:parent_id(name)')
              .eq('parent_id', widget.parentId)
              .eq('is_visible', true)
              .order('name'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandRed));
            }
            final data = snapshot.data ?? [];
            if (data.isEmpty)
              return const Center(child: Text("لا توجد أقسام فرعية حالياً"));

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final String subName = item['name'] ?? 'قسم غير مسمى';
                return InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubCategoryItemsPage(
                          categoryId: item['id'],
                          categoryName: subName,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: brandRed.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        subName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
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
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await supabase
          .from('products')
          .select('*')
          .eq('category_id', widget.categoryId)
          .eq('is_available', true);

      if (mounted) {
        setState(() {
          _products =
              (data as List).map((p) => ProductModel.fromJson(p)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                        color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)
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
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: brandRed))
                  : _products.isEmpty
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
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            return ProductCard(product: _products[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
