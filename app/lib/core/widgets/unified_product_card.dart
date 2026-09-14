import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red_market/core/providers/favorites_provider.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

class UnifiedProductCard extends ConsumerWidget {
  final ProductModel product;
  final bool isHorizontal;
  final bool showCartButton;

  const UnifiedProductCard({
    super.key,
    required this.product,
    this.isHorizontal = false,
    this.showCartButton = false,
  });

  // ✅ دالة معالجة الرابط لضمان ظهور الصور في الهوم بيج
  String _getValidImageUrl(String? url) {
    if (url == null || url.isEmpty)
      return 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png';
    if (url.startsWith('http')) return url;

    // تنظيف المسار وجلبه من مخزن سوبابيس (Storage)
    final supabase = Supabase.instance.client;
    String cleanPath = url.trim();
    if (cleanPath.contains('product-images/')) {
      cleanPath = cleanPath.split('product-images/').last;
    }
    return supabase.storage.from('product-images').getPublicUrl(cleanPath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesList = ref.watch(favoritesProvider);
    final isLiked = favoritesList.contains(product.id);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push(RoutePaths.productDetails, extra: product),
      child: Container(
        width: isHorizontal ? 160 : null,
        margin: isHorizontal
            ? const EdgeInsets.only(left: 15)
            : const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    _getValidImageUrl(
                        product.imageUrl), // ✅ استخدام الدالة المحدثة هنا
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox(
                      height: 140,
                      child: Center(
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () => ref
                        .read(favoritesProvider.notifier)
                        .toggleFavorite(product.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black54
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                if (product.isOffer)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "عرض خاص",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.oldPrice != null &&
                                product.oldPrice! > product.price)
                              PriceWidget(
                                price: product.price,
                                fontSize: 13,
                              ),
                            PriceWidget(
                              price: product.price,
                              fontSize: 13,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.star, color: Colors.amber, size: 14),
                          SizedBox(width: 2),
                          Text("4.5",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo')),
                        ],
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text("تم إضافة ${product.name} إلى السلة"),
                              backgroundColor: const Color(0xFFD32027),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        },
                        child: showCartButton
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32027),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.shopping_cart_outlined,
                                    color: Colors.white, size: 16),
                              )
                            : const Icon(Icons.add_circle,
                                color: Color(0xFFD32027), size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
