import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:red_market/features/auth/presentation/login_screen.dart';
import 'package:red_market/core/widgets/comments_sheet.dart';
import 'package:red_market_core/red_market_core.dart';
import 'dart:async';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final ProductModel? product;
  final String? productId;

  const ProductDetailsPage({
    super.key,
    this.product,
    this.productId,
  });

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  final supabase = Supabase.instance.client;

  bool isFavorite = false;
  bool isLiked = false;
  Timer? _flashTimer;
  Duration _remainingTime = Duration.zero;
  int likesCount = 0;
  bool _isLoading = true;

  ProductModel? _currentProduct;
  /// الصورة المعروضة حالياً في الإطار الكبير
  int _activeImage = 0;

  /// الصورة الرئيسية ثم الإضافية — بلا تكرار ولا فراغ
  List<String> get _images {
    final p = _currentProduct;
    if (p == null) return const [];
    final list = <String>[];
    final main = p.imageUrl ?? '';
    if (main.trim().length > 10) list.add(main);
    for (final u in p.imagesUrl) {
      if (u.trim().length > 10 && !list.contains(u)) list.add(u);
    }
    return list;
  }
  String? _realStoreName;
  String? _merchantId;
  final TextEditingController _otherReasonController = TextEditingController();
  String? _selectedReason;

  // ✅ تعليقات العرض
  int _commentsCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (widget.product != null) {
      _currentProduct = widget.product;
      likesCount = widget.product!.likesCount ?? 0;
      _isLoading = false;
      _fetchLatestProductDetails();
    } else if (widget.productId != null) {
      await _fetchLatestProductDetails();
    }

    _recordProductView();
    _checkInteractionStates();
    _loadCommentsCount();
    _startFlashTimer();
  }

  Future<void> _loadCommentsCount() async {
    try {
      final pid = _productId();
      if (pid.isEmpty) return;
      final res = await supabase
          .from('product_comments')
          .select('id')
          .eq('product_id', pid);
      if (mounted) {
        setState(() => _commentsCount = (res as List).length);
      }
    } catch (e) {
      debugPrint("Error loading comments count: $e");
    }
  }

  Future<void> _fetchLatestProductDetails() async {
    try {
      final String targetId = widget.productId ?? widget.product?.id ?? '';
      if (targetId.isEmpty) return;

      final productResponse = await supabase
          .from('products')
          .select()
          .eq('id', targetId)
          .maybeSingle();

      if (productResponse != null && mounted) {
        setState(() {
          _currentProduct = ProductModel.fromJson(productResponse);
          likesCount = _currentProduct!.likesCount ?? 0;
          _merchantId = productResponse['merchant_id']?.toString();
          _isLoading = false;
        });

        if (_merchantId != null) {
          final merchantResponse = await supabase
              .from('merchants')
              .select('store_name')
              .eq('id', _merchantId!)
              .maybeSingle();

          if (merchantResponse != null && mounted) {
            setState(() {
              final String? dbStoreName = merchantResponse['store_name'];
              if (dbStoreName != null && dbStoreName.trim().isNotEmpty) {
                _realStoreName = dbStoreName;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkInteractionStates() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final String pid = _productId();
      if (pid.isEmpty) return;

      final favData = await supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('product_id', pid)
          .maybeSingle();
      final likeData = await supabase
          .from('product_likes')
          .select()
          .eq('user_id', userId)
          .eq('product_id', pid)
          .maybeSingle();
      if (mounted) {
        setState(() {
          isFavorite = favData != null;
          isLiked = likeData != null;
        });
      }
    } catch (e) {
      debugPrint("Error interaction: $e");
    }
  }

  Future<void> _toggleLike() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _protectedAction(() {});
      return;
    }
    setState(() {
      isLiked = !isLiked;
      isLiked ? likesCount++ : likesCount--;
    });
    try {
      if (isLiked) {
        await supabase
            .from('product_likes')
            .insert({'user_id': userId, 'product_id': _productId()});
      } else {
        await supabase
            .from('product_likes')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', _productId());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
          isLiked ? likesCount++ : likesCount--;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _protectedAction(() {});
      return;
    }
    setState(() => isFavorite = !isFavorite);
    try {
      if (isFavorite) {
        await supabase
            .from('favorites')
            .insert({'user_id': userId, 'product_id': _productId()});
      } else {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', _productId());
      }
    } catch (e) {
      if (mounted) setState(() => isFavorite = !isFavorite);
    }
  }

  Future<void> _shareProduct() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final pid = _productId();
      if (pid.isEmpty) return;

      final String shareText =
          '${_currentProduct?.name ?? ''}\nالسعر: ${_currentProduct?.price ?? ''} ر.س\n${_currentProduct?.productUrl ?? ''}';

      await Share.share(shareText);

      await supabase.from('product_shares').insert({
        'product_id': pid,
        'merchant_id': _merchantId,
        'user_id': userId,
        'shared_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("❌ Share Error: $e");
    }
  }

  void _showComments() {
    _protectedAction(() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CommentsSheet(
          targetId: _productId(),
          targetType: 'product',
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      );
    });
  }

  void _showReportOptions(BuildContext context) {
    _selectedReason = null;
    _otherReasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30))),
          padding: EdgeInsets.only(
              top: 20,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("إبلاغ عن محتوى",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo')),
              const SizedBox(height: 25),
              _buildReportItem(
                  setModalState,
                  Icons.monetization_on_outlined,
                  "السعر مختلف",
                  Colors.green,
                  "السعر المعروض غير مطابق للحقيقة"),
              _buildReportItem(
                  setModalState,
                  Icons.link_off_rounded,
                  "رابط عرض مختلف",
                  Colors.blue,
                  "الرابط يوجه لعرض أو صفحة أخرى"),
              _buildReportItem(setModalState, Icons.gavel_rounded, "عرض مخالف",
                  Colors.red, "محتوى ينتهك سياسة المنصة"),
              const SizedBox(height: 15),
              TextField(
                controller: _otherReasonController,
                maxLines: 2,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                    hintText: "سبب آخر أو تفاصيل إضافية...",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32027),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      String finalReason =
                          _selectedReason ?? _otherReasonController.text;
                      if (finalReason.isEmpty) return;
                      Navigator.pop(context);
                      await _submitReport(finalReason);
                    },
                    child: const Text("إرسال البلاغ",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportItem(StateSetter setModalState, IconData icon,
      String title, Color color, String subtitle) {
    bool isSelected = _selectedReason == title;
    return ListTile(
      onTap: () => setModalState(() => _selectedReason = title),
      leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, fontFamily: 'Cairo')),
      trailing: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? const Color(0xFFD32027) : Colors.grey.shade300),
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('reports').insert({
        'reporter_id': userId,
        'target_id': _productId(),
        'target_type': 'product',
        'reason': reason,
        'status': 'pending'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("تم استلام بلاغك بنجاح"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("❌ Report Error: $e");
    }
  }

  void _protectedAction(VoidCallback onSuccess) {
    if (supabase.auth.currentUser != null) {
      onSuccess();
    } else {
      showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const LoginScreen(isBottomSheet: true))
          .then((value) {
        if (value == true && mounted) onSuccess();
      });
    }
  }

  void _startFlashTimer() {
    final expiry = _currentProduct?.flashSaleExpiry;
    if (expiry == null || !(_currentProduct?.isFlashSale ?? false)) return;
    _remainingTime = expiry.difference(DateTime.now());
    if (_remainingTime.isNegative) {
      _remainingTime = Duration.zero;
      return;
    }
    _flashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingTime = expiry.difference(DateTime.now());
        if (_remainingTime.isNegative) {
          _remainingTime = Duration.zero;
          _flashTimer?.cancel();
        }
      });
    });
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  String _productId() => widget.productId ?? widget.product?.id ?? '';

  Future<void> _recordProductView() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final pid = _productId();
      if (pid.isEmpty) return;

      await supabase.from('user_views').upsert({
        'user_id': userId,
        'product_id': pid,
        'viewed_at': DateTime.now().toIso8601String()
      }, onConflict: 'user_id, product_id');

      await supabase.from('product_views').insert({
        'product_id': pid,
        'merchant_id': _merchantId,
        'viewer_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("❌ View Error: $e");
    }
  }

  String _getValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return supabase.storage
        .from('product-images')
        .getPublicUrl(url.replaceAll('product-images/', ''));
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _otherReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFD32027))),
      );
    }

    if (_currentProduct == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
            child: Text("العرض غير موجود",
                style: TextStyle(fontFamily: 'Cairo'))),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: _realStoreName != null
              ? InkWell(
                  onTap: () {
                    debugPrint("🔴 merchantId = $_merchantId");
                    if (_merchantId != null)
                      context.push('/merchant-store/$_merchantId');
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFFD32027),
                            size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text(_realStoreName!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87))),
                      ],
                    ),
                  ),
                )
              : null,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : Colors.black),
              onPressed: () => context.pop()),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: 350,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10))
                                ]),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.network(
                                    _getValidImageUrl(_images.isNotEmpty
                                        ? _images[_activeImage.clamp(
                                            0, _images.length - 1)]
                                        : (_currentProduct!.imageUrl ?? '')),
                                    fit: BoxFit.cover)),
                          ),
                          Positioned(
                              top: 15,
                              left: 15,
                              child: GestureDetector(
                                  onTap: () => _protectedAction(
                                      () => _showReportOptions(context)),
                                  child: const Icon(
                                      Icons.report_problem_rounded,
                                      color: Colors.orange,
                                      size: 30))),
                          if ((_currentProduct?.isFlashSale ?? false) &&
                              _remainingTime.inSeconds > 0)
                            Positioned(
                              top: 15,
                              right: 15,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFD32027).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 5),
                                    Text(_formatDuration(_remainingTime),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Cairo')),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ===== مصغّرات الصور — تظهر عند وجود أكثر من صورة =====
                    if (_images.length > 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.85,
                        child: Row(
                          children: List.generate(_images.length, (i) {
                            final selected = i == _activeImage;
                            return Expanded(
                              child: Padding(
                                padding:
                                    EdgeInsets.only(left: i < _images.length - 1
                                        ? 8
                                        : 0),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _activeImage = i),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFFD32027)
                                              : Colors.grey.shade300,
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(11),
                                        child: Image.network(
                                          _getValidImageUrl(_images[i]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: Text(_currentProduct!.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'))),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            PriceWidget(
                              price: _currentProduct!.price,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            if (_currentProduct!.oldPrice != null &&
                                _currentProduct!.oldPrice! >
                                    _currentProduct!.price)
                              PriceWidget(
                                price: _currentProduct!.oldPrice!,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("وصف العرض",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blueGrey)),
                        Row(
                          children: [
                            if (likesCount > 0)
                              Text("$likesCount",
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red)),
                            const SizedBox(width: 5),
                            GestureDetector(
                                onTap: _toggleLike,
                                child: Icon(
                                    isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: Colors.red,
                                    size: 35)),
                            const SizedBox(width: 12),
                            // ✅ زر التعليقات
                            GestureDetector(
                              onTap: _showComments,
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded,
                                      color: Colors.blueGrey, size: 30),
                                  if (_commentsCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text("$_commentsCount",
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            color: Colors.blueGrey)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                                onTap: _toggleFavorite,
                                child: Icon(
                                    isFavorite
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: Colors.blueGrey,
                                    size: 35)),
                            const SizedBox(width: 12),
                            GestureDetector(
                                onTap: _shareProduct,
                                child: const Icon(Icons.reply_rounded,
                                    color: Colors.blueGrey, size: 35)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_currentProduct!.description,
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 15,
                            fontFamily: 'Cairo',
                            height: 1.8)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: InkWell(
                onTap: () => _protectedAction(() async {
                  final String? urlString = _currentProduct!.productUrl;
                  if (urlString != null && urlString.isNotEmpty) {
                    final Uri url = Uri.parse(urlString);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD32027).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: const Color(0xFFD32027).withValues(alpha: 0.3))),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.open_in_new_rounded, color: Color(0xFFD32027)),
                      SizedBox(width: 10),
                      Text("زيارة رابط العرض",
                          style: TextStyle(
                              color: Color(0xFFD32027),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
