import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/core/services/banner_tracking.dart';

class MainWideBanner extends StatefulWidget {
  final PageController bannerController;

  const MainWideBanner({
    super.key,
    required this.bannerController,
  });

  @override
  State<MainWideBanner> createState() => _MainWideBannerState();
}

class _MainWideBannerState extends State<MainWideBanner> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await supabase
          .rpc('get_active_banners', params: {'p_type': 'wide'});

      if (!mounted) return;
      setState(() {
        _banners = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Wide banners error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// وجهة البنر عند الضغط
  void _openTarget(Map<String, dynamic> b) {
    BannerTracking.click(b['booking_id']?.toString());

    final String? productId = b['product_id']?.toString();
    final String? merchantId = b['merchant_id']?.toString();
    final String? categoryId = b['category_id']?.toString();
    final String target = (b['target_type'] ?? '').toString();

    // البنرات المشتراة: الوجهة صريحة
    if (target == 'product' &&
        productId != null &&
        productId.isNotEmpty) {
      context.push('/product-details/$productId');
      return;
    }
    if (target == 'store' && merchantId != null && merchantId.isNotEmpty) {
      context.push('/merchant-store/$merchantId');
      return;
    }

    // البنرات الداخلية: أول ربط متاح
    if (productId != null && productId.isNotEmpty) {
      context.push('/product-details/$productId');
    } else if (merchantId != null && merchantId.isNotEmpty) {
      context.push('/merchant-store/$merchantId');
    } else if (categoryId != null && categoryId.isNotEmpty) {
      context.push(
        RoutePaths.subCategories,
        extra: {
          'parentId': categoryId,
          'categoryName': b['title'] ?? 'العرض',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _banners.isEmpty) return _buildPlaceholder();

    return SizedBox(
      height: 190,
      child: PageView.builder(
        controller: widget.bannerController,
        itemCount: 10000,
        itemBuilder: (context, index) {
          final b = _banners[index % _banners.length];
          return _buildBannerItem(b);
        },
      ),
    );
  }

  Widget _buildBannerItem(Map<String, dynamic> banner) {
    final String imageUrl = (banner['image_url'] ?? '').toString();
    final String? bookingId = banner['booking_id']?.toString();
    final String key = 'wide-${banner['banner_id']}';

    return VisibilityDetector(
      key: Key(key),
      onVisibilityChanged: (info) {
        // يُحتسب الظهور حين يظهر البنر كاملاً
        if (info.visibleFraction >= 0.99) {
          BannerTracking.impression(bookingId);
        }
      },
      child: GestureDetector(
        onTap: () => _openTarget(banner),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFD32027)),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 40),
                    ),
                  )
                : Container(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
        height: 140,
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFFD32027), Color(0xFFE62E04)],
          ),
        ),
        child: const Center(
          child: Text(
            " رد ماركت ",
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
}
