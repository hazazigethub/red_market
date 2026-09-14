import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market_core/red_market_core.dart';

class FavouritesPage extends ConsumerStatefulWidget {
  const FavouritesPage({super.key});

  @override
  ConsumerState<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends ConsumerState<FavouritesPage> {
  final supabase = Supabase.instance.client;
  List<ProductModel> _favoriteProducts = [];
  List<Map<String, dynamic>> _followedStores = [];
  bool _isLoading = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteProducts();
    _fetchFollowedStores();
  }

  Future<void> _fetchFavoriteProducts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('favorites')
          .select('products(*)')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _favoriteProducts = List<Map<String, dynamic>>.from(data)
              .map((item) {
                if (item['products'] == null) return null;
                return ProductModel.fromJson(item['products']);
              })
              .whereType<ProductModel>()
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromFavorites(String productId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _favoriteProducts.removeWhere((p) => p.id == productId);
    });

    try {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      _fetchFavoriteProducts();
    }
  }

  /// يجلب المتاجر التي يتابعها المستخدم
  Future<void> _fetchFollowedStores() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('merchant_followers')
          .select('merchants(*)')
          .eq('user_id', userId);

      final list = List<Map<String, dynamic>>.from(data)
          .map((item) => item['merchants'])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (mounted) setState(() => _followedStores = list);
    } catch (e) {
      debugPrint('Followed stores error: $e');
    }
  }

  /// إلغاء متابعة متجر
  /// شريط التبويبات
  Widget _buildTabs() {
    final tabs = [
      "العروض (${_favoriteProducts.length})",
      "المتاجر (${_followedStores.length})",
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tabIndex == i;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFD32027)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFD32027)
                        : Colors.grey.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// شبكة المتاجر المتابَعة
  Widget _buildStoresGrid() {
    if (_followedStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined,
                size: 80, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              "لم تتابع أي متجر بعد",
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _followedStores.length,
      itemBuilder: (context, index) {
        final m = _followedStores[index];
        final logo = (m['logo_url'] ?? '').toString();
        final name = (m['store_name'] ?? 'متجر').toString();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: InkWell(
                onTap: () => context.push('/merchant-store/${m['id']}'),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFD32027)
                                .withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFF7F8FA),
                        backgroundImage:
                            logo.isNotEmpty ? NetworkImage(logo) : null,
                        child: logo.isEmpty
                            ? const Icon(Icons.store,
                                color: Color(0xFFD32027), size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ إضافة Directionality لضمان محاذاة العناصر العربية بشكل صحيح
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: const Text(
            "المفضلة",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          foregroundColor: const Color(0xFFD32027),
        ),
        body: Column(
          children: [
            _buildTabs(),
            Expanded(
              child: _tabIndex == 0 ? _buildBody() : _buildStoresGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFD32027)));
    }

    if (_favoriteProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 80, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              "لا توجد عناصر محفوظة",
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _favoriteProducts.length,
      itemBuilder: (context, index) =>
          _buildProductCard(_favoriteProducts[index]),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          context.push('/product-details', extra: product);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl ?? '',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8, // ✅ في RTL ستظهر في الزاوية العلوية (اليسار)
                    child: GestureDetector(
                      onTap: () => _removeFromFavorites(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_rounded,
                            color: Color(0xFFD32027), size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ الاسم وعداد الإعجابات (مطابق لصفحة المتجر)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text("${product.likesCount ?? 0}",
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontFamily: 'Cairo')),
                          const SizedBox(width: 4),
                          const Icon(Icons.favorite_rounded,
                              color: Color(0xFFD32027), size: 14),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ✅ السعر الحالي
                  PriceWidget(
                    price: product.price,
                    fontSize: 14,
                  ),
                  // ✅ السعر القديم (مطابق لصفحة المتجر)
                  if (product.oldPrice != null &&
                      product.oldPrice! > product.price)
                    PriceWidget(
                      price: product.oldPrice!,
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
