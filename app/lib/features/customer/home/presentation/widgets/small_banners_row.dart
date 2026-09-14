import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/core/services/banner_tracking.dart';

class SmallBannersRow extends StatefulWidget {
  final PageController smallBannerController;

  const SmallBannersRow({
    super.key,
    required this.smallBannerController,
  });

  @override
  State<SmallBannersRow> createState() => _SmallBannersRowState();
}

class _SmallBannersRowState extends State<SmallBannersRow> {
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
          .rpc('get_active_banners', params: {'p_type': 'small'});

      if (!mounted) return;
      setState(() {
        _banners = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Small banners error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTarget(Map<String, dynamic> b) {
    BannerTracking.click(b['booking_id']?.toString());

    final String? productId = b['product_id']?.toString();
    final String? merchantId = b['merchant_id']?.toString();
    final String? categoryId = b['category_id']?.toString();
    final String target = (b['target_type'] ?? '').toString();

    if (target == 'product' && productId != null && productId.isNotEmpty) {
      context.push('/product-details/$productId');
      return;
    }
    if (target == 'store' && merchantId != null && merchantId.isNotEmpty) {
      context.push('/merchant-store/$merchantId');
      return;
    }

    if (productId != null && productId.isNotEmpty) {
      context.push('/product-details/$productId');
    } else if (merchantId != null && merchantId.isNotEmpty) {
      context.push('/merchant-store/$merchantId');
    } else if (categoryId != null && categoryId.isNotEmpty) {
      context.push(
        RoutePaths.subCategories,
        extra: {
          'parentId': categoryId,
          'categoryName': b['title'] ?? 'قسم خاص',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _banners.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: widget.smallBannerController,
        itemCount: 10000,
        itemBuilder: (context, index) {
          final b = _banners[index % _banners.length];
          return _buildSmallBannerItem(b);
        },
      ),
    );
  }

  Widget _buildSmallBannerItem(Map<String, dynamic> banner) {
    final String url = (banner['image_url'] ?? '').toString();
    final String? bookingId = banner['booking_id']?.toString();
    final String key = 'small-${banner['banner_id']}';

    return VisibilityDetector(
      key: Key(key),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.99) {
          BannerTracking.impression(bookingId);
        }
      },
      child: GestureDetector(
        onTap: () => _openTarget(banner),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[50],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFD32027)),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child:
                          const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  )
                : Container(color: Colors.grey[200]),
          ),
        ),
      ),
    );
  }
}
