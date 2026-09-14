import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:red_market/features/customer/home/presentation/providers/recently_viewed_provider.dart';
import 'package:red_market_core/red_market_core.dart';

class ProductCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final double width;

  const ProductCard({super.key, required this.product, this.width = 140});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  final supabase = Supabase.instance.client;

  Timer? _timer;
  late Duration _remainingTime;

  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLikeLoading = false;
  int _viewsCount = 0;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    if (widget.product.isFlashSale) {
      _startTimer();
    }
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    final userId = supabase.auth.currentUser?.id;
    final pid = widget.product.id;
    if (pid.isEmpty) return;

    try {
      final countRes = await supabase
          .from('product_likes')
          .select('product_id')
          .eq('product_id', pid);
      final int realCount = (countRes as List).length;

      bool liked = false;
      if (userId != null) {
        final likeRes = await supabase
            .from('product_likes')
            .select()
            .eq('user_id', userId)
            .eq('product_id', pid)
            .maybeSingle();
        liked = likeRes != null;
      }

      if (mounted) {
        setState(() {
          _likesCount = realCount;
          _isLiked = liked;
        });
      }

      final viewsRes = await supabase
          .from('product_views')
          .select('product_id')
          .eq('product_id', pid);
      if (mounted) {
        setState(() => _viewsCount = (viewsRes as List).length);
      }
    } catch (e) {
      debugPrint("Error loading like state: $e");
    }
  }

  Future<void> _toggleLike() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (_isLikeLoading) return;

    setState(() => _isLikeLoading = true);

    final bool currentLiked = _isLiked;
    final int currentCount = _likesCount;
    final int newCount = currentLiked
        ? (currentCount > 0 ? currentCount - 1 : 0)
        : currentCount + 1;

    setState(() {
      _isLiked = !currentLiked;
      _likesCount = newCount;
    });

    try {
      if (!currentLiked) {
        await supabase.from('product_likes').insert({
          'user_id': userId,
          'product_id': widget.product.id,
        });
      } else {
        await supabase
            .from('product_likes')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', widget.product.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = currentLiked;
          _likesCount = currentCount;
        });
      }
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  void _calculateRemainingTime() {
    if (widget.product.flashSaleExpiry != null) {
      _remainingTime =
          widget.product.flashSaleExpiry!.difference(DateTime.now());
      if (_remainingTime.isNegative) _remainingTime = Duration.zero;
    } else {
      _remainingTime = Duration.zero;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
        });
      }
      if (_remainingTime.inSeconds <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}م';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}ك';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await RecentlyViewedNotifier.addProduct(ref, widget.product);
        if (context.mounted) {
          context.push(RoutePaths.productDetails, extra: widget.product);
        }
      },
      child: Container(
        width: widget.width,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ صورة العرض
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 1 / 1,
                    child: Image.network(
                      widget.product.imageUrl ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(Icons.image_not_supported, size: 30),
                      ),
                    ),
                  ),
                ),
                if (widget.product.isFlashSale && _remainingTime.inSeconds > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32027).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.white, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(_remainingTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.product.oldPrice != null &&
                    widget.product.oldPrice! > widget.product.price)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32027),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${(((widget.product.oldPrice! - widget.product.price) / widget.product.oldPrice!) * 100).round()}%",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ✅ المعلومات
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ اسم العرض
                  Text(
                    widget.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ✅ صف السعر + الأيقونات
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ✅ السعر والخصم
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PriceWidget(
                              price: widget.product.price,
                              fontSize: 12,
                            ),
                            if (widget.product.oldPrice != null &&
                                widget.product.oldPrice! >
                                    widget.product.price) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: PriceWidget(
                                      price: widget.product.oldPrice!,
                                      fontSize: 10,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 4),

                      // ✅ الأيقونات: إعجاب فوق — مشاهدة تحت
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: _toggleLike,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_likesCount > 0)
                                  Text(
                                    '$_likesCount',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFD32027),
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(width: 3),
                                Icon(
                                  _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: const Color(0xFFD32027),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_viewsCount > 0)
                                Text(
                                  _formatCount(_viewsCount),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.remove_red_eye_outlined,
                                color: Colors.blueGrey,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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
