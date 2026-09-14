import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/features/customer/home/presentation/pages/product_details_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:red_market/features/auth/presentation/login_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/core/services/visit_logger.dart';
import 'package:red_market/features/customer/home/presentation/pages/merchant_reels_page.dart';

class StoreDetailsPage extends ConsumerStatefulWidget {
  final String merchantId;
  const StoreDetailsPage({super.key, required this.merchantId});

  @override
  ConsumerState<StoreDetailsPage> createState() => _StoreDetailsPageState();
}

class _StoreDetailsPageState extends ConsumerState<StoreDetailsPage> {
  final supabase = Supabase.instance.client;
  MerchantModel? _merchant;
  int _selectedCategoryIndex = 0;

  bool _isFollowing = false;
  int _followersCount = 0;
  bool _followBusy = false;

  String _storeDescription = "";
  String? _delayLabel;
  Color _delayColor = Colors.grey;
  bool _showDelayBadge = false;

  String? _selectedStoreReason;
  final TextEditingController _storeOtherReasonController =
      TextEditingController();

  List<String> _categories = ["الكل"];
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;

  final Color redMarketPrimary = const Color(0xFFD32027);

  @override
  void initState() {
    super.initState();
    _loadFollowState();
    _loadInitialData();
    _recordStoreVisit();
  }

  Future<void> _recordStoreVisit() =>
      VisitLogger.log(
        pageName: 'store',
        merchantId: widget.merchantId,
      );

  Future<void> _loadInitialData() async {
    await _loadStoreData();
  }

  @override
  void dispose() {
    _storeOtherReasonController.dispose();
    super.dispose();
  }

  void _protectedAction(VoidCallback onSuccess) {
    if (supabase.auth.currentUser != null) {
      onSuccess();
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LoginScreen(isBottomSheet: true),
      ).then((value) {
        if (value == true && mounted) onSuccess();
      });
    }
  }

  void _showStoreReportOptions(BuildContext context) {
    _selectedStoreReason = null;
    _storeOtherReasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
              const Text("إبلاغ عن المتجر",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo')),
              const SizedBox(height: 25),
              _buildStoreReportItem(
                  setModalState,
                  Icons.link_off_rounded,
                  "رابط المتجر مختلف",
                  Colors.indigo,
                  "الرابط لا يوجه للمتجر الصحيح"),
              _buildStoreReportItem(
                  setModalState,
                  Icons.security_update_warning_rounded,
                  "اشتباه احتيال",
                  redMarketPrimary,
                  "نشاط مريب أو محاولة خداع"),
              const SizedBox(height: 15),
              TextField(
                controller: _storeOtherReasonController,
                maxLines: 2,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "سبب آخر أو تفاصيل إضافية...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: redMarketPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (_selectedStoreReason == null &&
                        _storeOtherReasonController.text.isEmpty) return;
                    String finalReason = _selectedStoreReason ??
                        _storeOtherReasonController.text;
                    Navigator.pop(context);
                    await _submitReport(
                        widget.merchantId, 'merchant', finalReason);
                  },
                  child: const Text("إرسال البلاغ",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreReportItem(StateSetter setModalState, IconData icon,
      String title, Color color, String subtitle) {
    bool isSelected = _selectedStoreReason == title;
    return ListTile(
      onTap: () => setModalState(() => _selectedStoreReason = title),
      leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: redMarketPrimary)
          : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
    );
  }

  Future<void> _submitReport(
      String targetId, String type, String reason) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('reports').insert({
        'reporter_id': userId,
        'target_id': targetId,
        'target_type': type,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String()
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("تم استلام بلاغك بنجاح"),
            backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("❌ Report error: $e");
    }
  }

  Future<void> _loadStoreData() async {
    try {
      final merchRes = await supabase
          .from('merchants')
          .select()
          .eq('id', widget.merchantId)
          .maybeSingle();
      if (merchRes == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final prodData = await supabase
          .from('products')
          .select('*, product_categories(id, name)')
          .eq('merchant_id', widget.merchantId)
          .eq('is_available', true)
          .or('is_banned.eq.false,is_banned.is.null')
          // العروض المجدولة تُخفى حتى موعدها
          .or('flash_sale_start.is.null,flash_sale_start.lte.'
              '${DateTime.now().toIso8601String()}');

      if (mounted) {
        setState(() {
          _merchant = MerchantModel.fromJson(merchRes);
          _storeDescription = _merchant!.description;
          _allProducts =
              (prodData as List).map((e) => ProductModel.fromJson(e)).toList();
          final storeCategories = <String>{};
          for (var p in prodData) {
            final storeCat = p['store_category'];
            if (storeCat != null && storeCat.toString().isNotEmpty)
              storeCategories.add(storeCat.toString());
          }
          _categories = ["الكل", ...storeCategories.toList()..sort()];
          _filteredProducts = _allProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading store: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _filteredProducts = index == 0
          ? _allProducts
          : _allProducts
              .where((p) => p.storeCategory == _categories[index])
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32027)))
            : _merchant == null
                ? const Center(child: Text("المتجر غير موجود"))
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        leading: IconButton(
                            icon:
                                const Icon(Icons.arrow_back_ios_new, size: 20),
                            onPressed: () => Navigator.pop(context)),
                        title: Text(_merchant!.storeName,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        centerTitle: true,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.reply_rounded,
                                color: Color(0xFFD32027), size: 30),
                            onPressed: () async {
                              await Share.share(
                                  '${_merchant?.storeName ?? ''}\n${_merchant?.description ?? ''}');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.report_gmailerrorred_rounded,
                                color: Colors.orange, size: 30),
                            onPressed: () => _protectedAction(
                                () => _showStoreReportOptions(context)),
                          ),
                        ],
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildStoreHeader(isDark),
                            _buildFollowRow(isDark),
                            const SizedBox(height: 20),
                            _buildCategoryTabs(isDark),
                          ],
                        ),
                      ),
                      _buildProductsGrid(),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
      ),
    );
  }

  /// يجلب حالة المتابعة وعدد المتابعين
  Future<void> _loadFollowState() async {
    try {
      final merchantRes = await supabase
          .from('merchants')
          .select('followers_count')
          .eq('id', widget.merchantId)
          .maybeSingle();

      final userId = supabase.auth.currentUser?.id;
      bool following = false;

      if (userId != null) {
        final row = await supabase
            .from('merchant_followers')
            .select('id')
            .eq('merchant_id', widget.merchantId)
            .eq('user_id', userId)
            .maybeSingle();
        following = row != null;
      }

      if (!mounted) return;
      setState(() {
        _followersCount = (merchantRes?['followers_count'] as int?) ?? 0;
        _isFollowing = following;
      });
    } catch (e) {
      debugPrint('Follow state error: $e');
    }
  }

  /// متابعة المتجر أو إلغاؤها
  Future<void> _toggleFollow() async {
    if (_followBusy) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LoginScreen(isBottomSheet: true),
      ).then((_) => _loadFollowState());
      return;
    }

    setState(() => _followBusy = true);
    try {
      if (_isFollowing) {
        await supabase
            .from('merchant_followers')
            .delete()
            .eq('merchant_id', widget.merchantId)
            .eq('user_id', userId);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followersCount = (_followersCount - 1).clamp(0, 1 << 30);
          });
        }
      } else {
        await supabase.from('merchant_followers').insert({
          'merchant_id': widget.merchantId,
          'user_id': userId,
        });
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _followersCount = _followersCount + 1;
          });
        }
      }
    } catch (e) {
      debugPrint('Toggle follow error: $e');
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  /// صفّ الإحصاءات — العدّاد نفسه هو الزر، والأيقونتان بجانبه
  Widget _buildFollowRow(bool isDark) {
    final muted = isDark ? Colors.white54 : Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // 1) الفيديوهات — بلون الهوية
          IconButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MerchantReelsPage(merchantId: widget.merchantId))),
            tooltip: "فيديوهات المتجر",
            icon: Image.asset(
              'assets/images/film_icon.png',
              width: 34,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 16),

          // 2) عدد العروض
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${_filteredProducts.length}",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text("عرض",
                  style: TextStyle(
                      fontSize: 12, fontFamily: 'Cairo', color: muted)),
            ],
          ),

          const SizedBox(width: 28),

          // 3) المتابعة — الرقم زرّ
          GestureDetector(
            onTap: _followBusy ? null : _toggleFollow,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$_followersCount",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isFollowing ? Icons.how_to_reg : Icons.person_add_alt,
                      size: 13,
                      color: _isFollowing ? redMarketPrimary : muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _isFollowing ? "تمت المتابعة" : "متابعة",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        color: _isFollowing ? redMarketPrimary : muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildStoreHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: redMarketPrimary.withValues(alpha: 0.4), width: 1.5)),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFF7F8FA),
              backgroundImage: _merchant!.logoUrl.isNotEmpty
                  ? NetworkImage(_merchant!.logoUrl)
                  : null,
              child: _merchant!.logoUrl.isEmpty
                  ? Icon(Icons.store, color: redMarketPrimary, size: 28)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _storeDescription.isNotEmpty
                      ? _storeDescription
                      : "لا يوجد وصف للمتجر",
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'Cairo',
                      height: 1.6),
                ),
                if (_showDelayBadge) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: _delayColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(_delayLabel!,
                        style: TextStyle(
                            fontSize: 11,
                            color: _delayColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    // ✅ لون خلفية الصفحة الحالي
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // ✅ تابات الأقسام
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4, right: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () => _filterProducts(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? redMarketPrimary
                          : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? redMarketPrimary
                              : Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_filteredProducts.isEmpty)
      return const SliverFillRemaining(
          child: Center(child: Text("لا توجد عروض")));

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = _filteredProducts[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductDetailsPage(product: product))),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: redMarketPrimary.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15)),
                        child: CachedNetworkImage(
                            imageUrl: product.imageUrl ?? "",
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[100])),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          fontFamily: 'Cairo'))),
                              Row(children: [
                                Text("${product.likesCount ?? 0}",
                                    style: const TextStyle(
                                        fontSize: 12, fontFamily: 'Cairo')),
                                const SizedBox(width: 4),
                                Icon(Icons.favorite_rounded,
                                    color: redMarketPrimary, size: 14),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 4),
                          PriceWidget(
                              price: product.price,
                              fontSize: 14,
                              color: redMarketPrimary),
                          if (product.oldPrice != null &&
                              product.oldPrice! > product.price)
                            Row(children: [
                              PriceWidget(
                                  price: product.oldPrice!,
                                  fontSize: 11,
                                  color: Colors.grey),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  "${(((product.oldPrice! - product.price) / product.oldPrice!) * 100).round()}%",
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo'),
                                ),
                              ),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: _filteredProducts.length,
        ),
      ),
    );
  }
}
