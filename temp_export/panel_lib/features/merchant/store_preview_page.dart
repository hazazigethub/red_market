import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'products_page.dart';

class StorePreviewPage extends StatefulWidget {
  final String merchantId;
  const StorePreviewPage({super.key, required this.merchantId});

  @override
  State<StorePreviewPage> createState() => _StorePreviewPageState();
}

class _StorePreviewPageState extends State<StorePreviewPage> {
  final supabase = Supabase.instance.client;
  String _selectedCategoryName =
      "الكل"; // تغيير النوع إلى String ليتناسب مع التعديل الجديد
  bool _isLoading = true;
  Map<String, dynamic>? _merchantData;
  List<String> _categories = []; // تم تغيير النوع من CategoryItem إلى String
  List<ProductItem> _products = [];

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      // 1. جلب بيانات المتجر
      final merchantRes = await supabase
          .from('merchants')
          .select()
          .eq('id', widget.merchantId)
          .single();

      // 2. جلب عروض هذا التاجر (لاستخراج الأقسام منها)
      final productsRes = await supabase
          .from('products')
          .select()
          .eq('merchant_id', widget.merchantId)
          .eq('is_available', true);

      if (mounted) {
        setState(() {
          _merchantData = merchantRes;
          _products = (productsRes as List)
              .map((e) => ProductItem.fromJson(e))
              .toList();

          // 3. استخراج الأقسام الفريدة من قائمة العروض المجلوبة
          _categories = _products
              .map((p) => p.storeCategory)
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading store data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50))));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildModernAppBar(),
            SliverToBoxAdapter(child: _buildStoreInfoSection()),
            SliverPersistentHeader(
              pinned: true,
              delegate:
                  _SliverAppBarDelegate(child: _buildModernCategoriesBar()),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _buildModernProductsGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 50, bottom: 16),
        centerTitle: false,
        title: Text(
          _merchantData?['store_name'] ?? "اسم المتجر",
          style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'Cairo'),
        ),
        background: Container(color: Colors.white),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.black, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
    );
  }

  Widget _buildStoreInfoSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStoreLogo(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _merchantData?['store_description'] ??
                            "وصف المتجر يظهر هنا بشكل احترافي.",
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontFamily: 'Cairo')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text(_merchantData?['address'] ?? "الموقع غير متوفر",
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontFamily: 'Cairo')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStoreLogo() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: const Color(0xFFF44336),
        backgroundImage: (_merchantData?['logo_url'] != null &&
                _merchantData!['logo_url'].toString().isNotEmpty)
            ? NetworkImage(_merchantData!['logo_url'])
            : null,
        child: (_merchantData?['logo_url'] == null ||
                _merchantData!['logo_url'].toString().isEmpty)
            ? const Icon(Icons.store, color: Colors.white, size: 30)
            : null,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statBadge("4.9", Icons.star_rounded, const Color(0xFFFFB800)),
        _statBadge(
            "2.4 كم", Icons.directions_bike_rounded, const Color(0xFF1890FF)),
        _statBadge(
            "مجاناً", Icons.local_shipping_rounded, const Color(0xFF13C2C2)),
        _statBadge("30 دقيقة", Icons.access_time_filled_rounded,
            const Color(0xFFF5222D)),
      ],
    );
  }

  Widget _statBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildModernCategoriesBar() {
    return Container(
      color: Colors.white,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          bool isAll = index == 0;
          String title = isAll ? "الكل" : _categories[index - 1];

          bool isSelected = _selectedCategoryName == title;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryName = title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsetsDirectional.only(end: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color:
                        isSelected ? Colors.transparent : Colors.grey.shade200),
              ),
              child: Center(
                child: Text(title,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Cairo')),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernProductsGrid() {
    // الفلترة باستخدام اسم القسم النصي (storeCategory)
    List<ProductItem> filtered = _selectedCategoryName == "الكل"
        ? _products
        : _products
            .where((p) => p.storeCategory == _selectedCategoryName)
            .toList();

    if (filtered.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 50),
          child: Center(
              child: Text("لا توجد عروض في هذا القسم",
                  style: TextStyle(fontFamily: 'Cairo'))),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildModernProductCard(filtered[index]),
        childCount: filtered.length,
      ),
    );
  }

  Widget _buildModernProductCard(ProductItem product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: const Icon(Icons.favorite_border_rounded,
                        size: 18, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Cairo')),
                // عرض اسم القسم النصي مباشرة
                Text(
                  product.storeCategory,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 10, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PriceWidget(
                      price: product.price,
                      fontSize: 15,
                      color: const Color(0xFF4CAF50),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 18,
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
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverAppBarDelegate({required this.child});

  @override
  double get minExtent => 60.0;
  @override
  double get maxExtent => 60.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
