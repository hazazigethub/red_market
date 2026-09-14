import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_market_core/red_market_core.dart';
import 'product_card.dart';

class InfiniteProductsGrid extends StatefulWidget {
  final ScrollController scrollController;

  const InfiniteProductsGrid({super.key, required this.scrollController});

  @override
  State<InfiniteProductsGrid> createState() => _InfiniteProductsGridState();
}

class _InfiniteProductsGridState extends State<InfiniteProductsGrid> {
  final supabase = Supabase.instance.client;
  List<ProductModel> _products = [];
  bool _isLoading = false;
  int _currentOffset = 0;
  final int _pageSize = 12;

  @override
  void initState() {
    super.initState();
    _fetchSmartProducts();
    // ربط المستمع للسكروول
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    // ✅ تصحيح الخطأ: إزالة المستمع عند إغلاق الودجت لمنع المناداة بعد الـ dispose
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (widget.scrollController.position.pixels >=
        widget.scrollController.position.maxScrollExtent - 400) {
      _fetchSmartProducts();
    }
  }

  Future<void> _fetchSmartProducts() async {
    // منع الاستدعاء المتكرر أو الاستدعاء بعد إغلاق الصفحة
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      // ✅ تعديل النوع ليكون مرناً أثناء الجلب
      List<int> interests = [];

      // 1. جلب التفضيلات
      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('preferred_categories')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null &&
            profile['preferred_categories'] != null &&
            mounted) {
          // ✅ تحويل آمن يضمن عدم حدوث خطأ 'String' is not a subtype of 'int'
          final List<dynamic> rawCats = profile['preferred_categories'] as List;
          interests.addAll(
              rawCats.map((e) => int.tryParse(e.toString())).whereType<int>());
        }
      }

      // 2. جلب معرفات الأقسام من التفضيلات المحلية
      final prefs = await SharedPreferences.getInstance();
      final lastViewedCats =
          prefs.getStringList('last_viewed_category_ids') ?? [];
      // ✅ تحويل آمن لمعرفات الأقسام المحلية
      interests.addAll(
          lastViewedCats.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0));

      // 3. بناء الاستعلام
      var query = supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .or('is_banned.eq.false,is_banned.is.null');

      if (interests.isNotEmpty) {
        query = query.filter('category_id', 'in', interests.toSet().toList());
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(_currentOffset, _currentOffset + _pageSize - 1);

      // ✅ فحص mounted بعد جلب البيانات وقبل عمل setState
      if (!mounted) return;

      List<ProductModel> newProducts =
          (data as List).map((p) => ProductModel.fromJson(p)).toList();

      newProducts.shuffle();

      setState(() {
        _products.addAll(newProducts);
        _currentOffset += _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching smart products: $e");
      // ✅ فحص mounted حتى في حالة الخطأ
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty && _isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFFD32027))),
      );
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 215,
            crossAxisSpacing: 2,
            mainAxisSpacing: 10,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: _products[index],
              width: 140,
            );
          },
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Color(0xFFD32027)),
          ),
      ],
    );
  }
}
