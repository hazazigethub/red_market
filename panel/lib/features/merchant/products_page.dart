import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:red_market_core/red_market_core.dart';
import 'merchant_subscriptions_page.dart';

const Color brandRed = Color(0xFFD32027);

class ProductItem {
  final String id;
  String name;
  String categoryId;
  String? subCategoryId;
  String storeCategory;
  double price;
  double? oldPrice;
  String description;
  String productUrl;
  bool isAvailable;
  String imageUrl;

  /// صور إضافية — حتى ثلاث بجانب الرئيسية
  List<String> imagesUrl;
  bool isFlashSale;
  DateTime? flashSaleExpiry;
  DateTime? flashSaleStart;

  ProductItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.subCategoryId,
    required this.storeCategory,
    required this.price,
    this.oldPrice,
    required this.description,
    required this.productUrl,
    required this.isAvailable,
    required this.imageUrl,
    this.imagesUrl = const [],
    this.isFlashSale = false,
    this.flashSaleExpiry,
    this.flashSaleStart,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      subCategoryId: json['sub_category_id']?.toString(),
      storeCategory: json['store_category'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      description: json['description'] ?? '',
      productUrl: json['product_url'] ?? '',
      isAvailable: json['is_available'] ?? true,
      imageUrl:
          (json['image_url'] != null &&
              json['image_url'].toString().trim().length > 10)
          ? json['image_url'].toString()
          : 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png',
      imagesUrl:
          (json['images_url'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().length > 10)
              .toList() ??
          const [],
      isFlashSale: json['is_flash_sale'] ?? false,
      flashSaleExpiry: json['flash_sale_expiry'] != null
          ? DateTime.parse(json['flash_sale_expiry']).toLocal()
          : null,
      flashSaleStart: json['flash_sale_start'] != null
          ? DateTime.parse(json['flash_sale_start']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson(String merchantId) {
    return {
      'merchant_id': merchantId,
      'name': name,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'store_category': storeCategory,
      'price': price,
      'old_price': oldPrice,
      'description': description,
      'product_url': productUrl,
      'is_available': isAvailable,
      'image_url': imageUrl,
      'images_url': imagesUrl,
      'is_flash_sale': isFlashSale,
      // تُحوَّل لتوقيت عالمي قبل الحفظ — وإلا زادت 3 ساعات
      'flash_sale_expiry': flashSaleExpiry?.toUtc().toIso8601String(),
      'flash_sale_start': flashSaleStart?.toUtc().toIso8601String(),
    };
  }
}

class CategoryItem {
  final String id;
  final String name;
  final String? storeCategoryId;

  CategoryItem({required this.id, required this.name, this.storeCategoryId});

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      storeCategoryId: json['store_category_id']?.toString(),
    );
  }
}

class ProductsPage extends StatefulWidget {
  final String? merchantId;
  const ProductsPage({super.key, this.merchantId});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // ✅ التبويب الرئيسي: عروض أو أقسام

  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  List<ProductItem> _productsList = [];
  List<CategoryItem> _mainCategories = [];
  List<CategoryItem> _allSubCategories = [];
  List<CategoryItem> _categoriesList = [];
  List<String> _myStoreCategories = [];
  bool _isLoading = true;
  String _selectedStoreCategory = "الكل";
  int _productLimit = 0;
  bool _isSubscriptionActive = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await _fetchProductLimit();
    await _fetchCategories();
    await _fetchProducts();
    _loadMyStoreCategories();
  }

  Future<void> _fetchProductLimit() async {
    try {
      final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;

      // ✅ إذا كان الأدمن يعاين متجر تاجر — صلاحيات كاملة
      if (widget.merchantId != null &&
          widget.merchantId != supabase.auth.currentUser?.id) {
        if (mounted) {
          setState(() {
            _isSubscriptionActive = true;
            _productLimit = 9999;
          });
        }
        return;
      }

      // الحد محفوظ في profiles عند إسناد الباقة
      final profile = await supabase
          .from('profiles')
          .select('max_products, is_subscription_active')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return;

      final active = profile['is_subscription_active'] ?? false;
      final limit = (profile['max_products'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _isSubscriptionActive = active;
          // التاجر يواصل الإدارة حتى لو انتهى اشتراكه،
          // والإخفاء عن العميل يتم عبر is_subscription_active
          _productLimit = limit;
        });
      }
    } catch (e) {
      debugPrint("خطأ في جلب حد العروض: $e");
    }
  }

  void _loadMyStoreCategories() {
    setState(() {
      _myStoreCategories = _productsList
          .map((p) => p.storeCategory)
          .where((sc) => sc.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  Future<void> _fetchProducts() async {
    try {
      final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('products')
          .select()
          .eq('merchant_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _productsList = (data as List)
              .map((e) => ProductItem.fromJson(e))
              .toList();
          _loadMyStoreCategories();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('PRODUCTS ERROR: $e | $st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await supabase.from('products').delete().eq('id', productId);
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "تم حذف العرض بنجاح",
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "خطأ في الحذف: $e",
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final merchantId = widget.merchantId ?? supabase.auth.currentUser?.id;

      final merchant = await supabase
          .from('merchants')
          .select('store_category_id')
          .eq('id', merchantId as Object)
          .maybeSingle();

      final storeCategoryId = merchant?['store_category_id'];

      // فروع تصنيف متجره فقط — لا كل التصنيفات
      final productData = storeCategoryId == null
          ? []
          : await supabase
                .from('product_categories')
                .select()
                .eq('parent_id', storeCategoryId)
                .order('name');

      if (mounted) {
        setState(() {
          _allSubCategories = (productData as List)
              .map((e) => CategoryItem.fromJson(e))
              .toList();
          _categoriesList = _allSubCategories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageFile.readAsBytes();
      await supabase.storage
          .from('product-images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      final String publicUrl = supabase.storage
          .from('product-images')
          .getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة: $e");
      return null;
    }
  }

  Future<void> _upsertProduct(
    ProductItem product, {
    bool isUpdate = false,
  }) async {
    final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;
    isUpdate
        ? await supabase
              .from('products')
              .update(product.toJson(userId))
              .eq('id', product.id)
        : await supabase.from('products').insert(product.toJson(userId));
    _fetchProducts();
  }

  void _showCategorySearchDialog(
    String? currentId,
    Function(CategoryItem) onSelect, {
    List<CategoryItem>? source,
    String title = "اختر التصنيف المعتمد للمنصة",
  }) {
    String searchQuery = "";
    final list = source ?? _categoriesList;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = list
                .where((c) => c.name.contains(searchQuery))
                .toList();
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: brandRed,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (v) => setDialogState(() => searchQuery = v),
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        hintText: "ابحث باسم التصنيف...",
                        prefixIcon: const Icon(Icons.search, color: brandRed),
                        filled: true,
                        fillColor: brandRed.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          bool isSelected = currentId == filtered[i].id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandRed.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? brandRed
                                    : Colors.grey.shade300,
                                radius: 5,
                              ),
                              title: Text(
                                filtered[i].name,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                onSelect(filtered[i]);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddStoreCategoryDialog() {
    final TextEditingController catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "إضافة قسم جديد لمتجري",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: brandRed,
            ),
          ),
          content: TextField(
            controller: catCtrl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: "اسم القسم (مثلاً: حلويات)...",
              prefixIcon: const Icon(Icons.folder_open, color: brandRed),
              filled: true,
              fillColor: brandRed.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "إلغاء",
                style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (catCtrl.text.isNotEmpty) {
                  setState(() {
                    _myStoreCategories.add(catCtrl.text);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "تأكيد",
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : !_isSubscriptionActive
            ? _buildSubscriptionRequired()
            : Column(
                children: [
                  // ✅ شريط الأدوات والتصنيفات
                  _buildFilterTabs(isDark),

                  // ✅ شريط عدد العروض
                  if (true)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _productsList.length >= _productLimit
                            ? Colors.red.withValues(alpha: 0.08)
                            : brandRed.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _productsList.length >= _productLimit
                              ? Colors.red.withValues(alpha: 0.3)
                              : brandRed.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: _productsList.length >= _productLimit
                                ? Colors.red
                                : brandRed,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "العروض: ${_productsList.length} / $_productLimit",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _productsList.length >= _productLimit
                                  ? Colors.red
                                  : brandRed,
                            ),
                          ),
                          if (_productsList.length >= _productLimit) ...[
                            const Spacer(),
                            const Text(
                              "وصلت للحد الأقصى",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  Expanded(
                    child: _buildProductsList(
                      _productsList
                          .where(
                            (p) =>
                                _selectedStoreCategory == "الكل" ||
                                p.storeCategory == _selectedStoreCategory,
                          )
                          .toList(),
                      isDark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSubscriptionRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: brandRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 60,
                color: brandRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "عروضك موقوفة مؤقتاً",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "لا يمكن عرض أو إدارة العروض بدون اشتراك فعّال. فعّل باقتك لتظهر عروضك للعملاء.",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.card_membership_rounded,
                color: Colors.white,
              ),
              label: const Text(
                "تفعيل الباقة",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MerchantSubscriptionsPage(),
                ),
              ).then((_) => _fetchInitialData()),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ الكرتان العلويتان
  Widget _buildFilterTabs(bool isDark) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterTab("الكل", isDark, label: "جميع العروض"),
          _buildActionSquare(
            icon: Icons.add_shopping_cart,
            label: "إضافة عرض",
            onTap: () => _onAddProduct(isDark),
          ),
          _buildActionSquare(
            icon: Icons.create_new_folder_outlined,
            label: "إضافة تصنيف",
            onTap: _showAddStoreCategoryDialog,
          ),
          ..._myStoreCategories.map((cat) => _buildFilterTab(cat, isDark)),
        ],
      ),
    );
  }

  /// يتحقق من الحدود قبل فتح نموذج إضافة عرض
  void _onAddProduct(bool isDark) {
    if (_productsList.length >= _productLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "وصلت للحد الأقصى ($_productLimit عرض). رقّ باقتك لإضافة المزيد.",
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_myStoreCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "يجب إضافة تصنيف لمتجرك أولاً قبل إضافة عروض",
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _showAddProductForm(isDark);
  }

  /// مربع إجراء (إضافة عرض / إضافة تصنيف)
  Widget _buildActionSquare({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: brandRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// خيارات تعديل أو حذف تصنيف
  void _showCategoryOptions(String catName) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            catName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: brandRed),
                title: const Text(
                  "تعديل الاسم",
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameCategoryDialog(catName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  "حذف التصنيف",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteCategory(catName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// نافذة تعديل اسم التصنيف
  void _showRenameCategoryDialog(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "تعديل اسم التصنيف",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "إلغاء",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandRed),
              onPressed: () async {
                final newName = ctrl.text.trim();
                if (newName.isEmpty || newName == oldName) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx);
                await _renameCategory(oldName, newName);
              },
              child: const Text(
                "حفظ",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// يعيد تسمية التصنيف في كل عروضه
  Future<void> _renameCategory(String oldName, String newName) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      await supabase
          .from('products')
          .update({'store_category': newName})
          .eq('merchant_id', uid)
          .eq('store_category', oldName);

      setState(() {
        final i = _myStoreCategories.indexOf(oldName);
        if (i != -1) _myStoreCategories[i] = newName;
        if (_selectedStoreCategory == oldName) {
          _selectedStoreCategory = newName;
        }
      });

      _fetchProducts();
    } catch (e) {
      debugPrint('Rename category error: $e');
    }
  }

  /// تأكيد حذف التصنيف
  void _confirmDeleteCategory(String catName) {
    final count = _productsList.where((p) => p.storeCategory == catName).length;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "حذف التصنيف",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          content: Text(
            count > 0
                ? "لا يمكن حذف التصنيف لأنه يحتوي على $count عرض. انقل العروض أو احذفها أولاً."
                : "سيتم حذف التصنيف \"$catName\". هل أنت متأكد؟",
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                count > 0 ? "حسناً" : "إلغاء",
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            ),
            if (count == 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _myStoreCategories.remove(catName);
                    if (_selectedStoreCategory == catName) {
                      _selectedStoreCategory = "الكل";
                    }
                  });
                },
                child: const Text(
                  "حذف",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isDark, {String? label}) {
    final bool isSelected = _selectedStoreCategory == title;
    final bool isAll = title == "الكل";

    return GestureDetector(
      onTap: () => setState(() => _selectedStoreCategory = title),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? brandRed
              : (isDark ? Colors.white10 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: brandRed, width: isSelected ? 0 : 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label ?? title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
            if (!isAll)
              Positioned(
                top: 2,
                left: 2,
                child: GestureDetector(
                  onTap: () => _showCategoryOptions(title),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.edit,
                      size: 13,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(List<ProductItem> filteredProducts, bool isDark) {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              "لا توجد عروض في هذا القسم حالياً",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
          ],
        ),
      );
    }
    // عرض البطاقة ثابت، والأعمدة تزيد مع اتساع الشاشة
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) =>
          _buildProductItem(filteredProducts[index], isDark),
    );
  }

  Widget _buildProductItem(ProductItem product, bool isDark) {
    final bool hasOld =
        product.oldPrice != null && product.oldPrice! > product.price;
    final int percent = hasOld
        ? (((product.oldPrice! - product.price) / product.oldPrice!) * 100)
              .round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: isDark ? Colors.white10 : Colors.grey.shade50,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 32,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Row(
                    children: [
                      _cardIconButton(
                        icon: Icons.edit,
                        color: Colors.blue,
                        onTap: () =>
                            _showAddProductForm(isDark, productToEdit: product),
                      ),
                      const SizedBox(width: 4),
                      _cardIconButton(
                        icon: Icons.delete_outline,
                        color: brandRed,
                        onTap: () => _confirmDelete(product),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 2,
                  child: Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: product.isAvailable,
                      activeColor: brandRed,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) async {
                        await supabase
                            .from('products')
                            .update({'is_available': val})
                            .eq('id', product.id);
                        _fetchProducts();
                      },
                    ),
                  ),
                ),
                if (product.isFlashSale)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: brandRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "عرض سريع",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.storeCategory.isNotEmpty)
                    Text(
                      product.storeCategory,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasOld)
                    Row(
                      children: [
                        Text(
                          product.oldPrice!.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontFamily: 'Cairo',
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            "$percent%",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  PriceWidget(
                    price: product.price,
                    fontSize: 14,
                    color: brandRed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// زر أيقونة صغير يوضع فوق صورة العرض
  Widget _cardIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  void _confirmDelete(ProductItem product) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "حذف العرض",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: Text(
            "هل أنت متأكد من رغبتك في حذف '${product.name}'؟ لا يمكن التراجع عن هذه العملية.",
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "إلغاء",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProduct(product.id);
              },
              child: const Text(
                "حذف الآن",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: brandRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductForm(bool isDark, {ProductItem? productToEdit}) {
    final nameController = TextEditingController(
      text: productToEdit?.name ?? "",
    );
    final oldPriceController = TextEditingController(
      text: productToEdit?.oldPrice?.toString() ?? "",
    );
    final priceController = TextEditingController(
      text: productToEdit?.price.toString() ?? "",
    );
    final discountInputController = TextEditingController();
    final urlController = TextEditingController(
      text: productToEdit?.productUrl ?? "",
    );
    final descController = TextEditingController(
      text: productToEdit?.description ?? "",
    );

    String? selectedCategoryId = productToEdit?.categoryId;
    String selectedCategoryName =
        _allSubCategories.any((c) => c.id == selectedCategoryId)
        ? _allSubCategories.firstWhere((c) => c.id == selectedCategoryId).name
        : "اضغط لاختيار التصنيف المعتمد...";

    // فرعي الفرعي — اختياري، تابع للتصنيف الفرعي أعلاه
    String? selectedSubCategoryId = productToEdit?.subCategoryId;
    String selectedSubCategoryName = "اضغط لاختيار الفرع (اختياري)";

    String? storeCategoryValue = productToEdit?.storeCategory;

    // أربع خانات: الأولى رئيسية والباقي اختيارية
    // كل خانة إمّا رابط موجود أو ملف مختار حديثاً
    final List<String?> slotUrls = List<String?>.filled(4, null);
    final List<XFile?> slotFiles = List<XFile?>.filled(4, null);

    if (productToEdit != null) {
      slotUrls[0] = productToEdit.imageUrl;
      for (var i = 0; i < productToEdit.imagesUrl.length && i < 3; i++) {
        slotUrls[i + 1] = productToEdit.imagesUrl[i];
      }
    }

    bool isSaving = false;
    String discountType = "fixed";
    bool showError = false;

    bool isFlashSale = productToEdit?.isFlashSale ?? false;
    DateTime? flashSaleExpiry = productToEdit?.flashSaleExpiry;
    DateTime? flashSaleStart = productToEdit?.flashSaleStart;
    // نشر مباشر أم مجدول
    bool isScheduled = productToEdit?.flashSaleStart != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          void calculateNewPrice() {
            double original = double.tryParse(oldPriceController.text) ?? 0;
            if (discountType == "percent") {
              double percent =
                  double.tryParse(discountInputController.text) ?? 0;
              double calculated = original - (original * (percent / 100));
              priceController.text = calculated > 0
                  ? calculated.toStringAsFixed(2)
                  : "0.00";
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "بيانات العرض",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ===== أربع خانات صور =====
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(4, (i) {
                      final file = slotFiles[i];
                      final url = slotUrls[i];
                      final hasAny = file != null || url != null;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i < 3 ? 8 : 0),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final img = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1024,
                                    imageQuality: 80,
                                  );
                                  if (img != null) {
                                    setModalState(() {
                                      slotFiles[i] = img;
                                      slotUrls[i] = null;
                                    });
                                  }
                                },
                                child: Container(
                                  height: 78,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    border: (showError && i == 0 && !hasAny)
                                        ? Border.all(
                                            color: Colors.red,
                                            width: 2,
                                          )
                                        : (i == 0
                                              ? Border.all(
                                                  color: brandRed,
                                                  width: 1.5,
                                                )
                                              : null),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: file != null
                                            ? const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 30,
                                              )
                                            : (url != null
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            11,
                                                          ),
                                                      child: Image.network(
                                                        url,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: 78,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.add_photo_alternate,
                                                      color:
                                                          Colors.grey.shade500,
                                                      size: 26,
                                                    )),
                                      ),
                                      if (hasAny)
                                        Positioned(
                                          top: 2,
                                          left: 2,
                                          child: GestureDetector(
                                            onTap: () => setModalState(() {
                                              slotFiles[i] = null;
                                              slotUrls[i] = null;
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 13,
                                                color: brandRed,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                i == 0 ? "الرئيسية" : "صورة ${i + 1}",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: i == 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: i == 0 ? brandRed : Colors.grey,
                                ),
                              ),
                              // تبديل الرئيسية — يظهر للخانات غير الأولى
                              if (i > 0 && hasAny)
                                GestureDetector(
                                  onTap: () => setModalState(() {
                                    final tf = slotFiles[0];
                                    final tu = slotUrls[0];
                                    slotFiles[0] = slotFiles[i];
                                    slotUrls[0] = slotUrls[i];
                                    slotFiles[i] = tf;
                                    slotUrls[i] = tu;
                                  }),
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      "اجعلها رئيسية",
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 9,
                                        color: brandRed,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 13),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 10),
                  _buildInput(
                    nameController,
                    "اسم العرض",
                    Icons.shopping_bag,
                    isDark,
                    showError,
                  ),
                  _buildInputMultiline(
                    descController,
                    "وصف العرض",
                    Icons.description,
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "* القسم الداخلي للمتجر (إلزامي)",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: brandRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value:
                        (storeCategoryValue != null &&
                            _myStoreCategories.contains(storeCategoryValue))
                        ? storeCategoryValue
                        : null,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    items: _myStoreCategories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) =>
                        setModalState(() => storeCategoryValue = newValue),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.storefront,
                        color: brandRed,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: (showError && storeCategoryValue == null)
                              ? Colors.red
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    hint: const Text(
                      "اختر القسم الداخلي للمتجر",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () =>
                        _showCategorySearchDialog(selectedCategoryId, (cat) {
                          setModalState(() {
                            selectedCategoryId = cat.id;
                            selectedCategoryName = cat.name;
                          });
                        }),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: brandRed.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: (showError && selectedCategoryId == null)
                              ? Colors.red.shade700
                              : brandRed.withValues(alpha: 0.1),
                          width: (showError && selectedCategoryId == null)
                              ? 2
                              : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category, color: brandRed, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedCategoryName,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(Icons.search, color: brandRed, size: 18),
                        ],
                      ),
                    ),
                  ),

                  // فرعي الفرعي — اختياري، يظهر فقط بعد اختيار الفرعي
                  if (selectedCategoryId != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        final subs = await supabase
                            .from('sup_product_subcategories')
                            .select()
                            .eq('parent_id', selectedCategoryId as Object)
                            .order('name');
                        final subList = (subs as List)
                            .map((e) => CategoryItem.fromJson(e))
                            .toList();

                        if (!context.mounted) return;
                        _showCategorySearchDialog(
                          selectedSubCategoryId,
                          (cat) {
                            setModalState(() {
                              selectedSubCategoryId = cat.id;
                              selectedSubCategoryName = cat.name;
                            });
                          },
                          source: subList,
                          title: "اختر الفرع (اختياري)",
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: brandRed.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: brandRed.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.subdirectory_arrow_left,
                              color: brandRed,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedSubCategoryName,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const Icon(Icons.search, color: brandRed, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: brandRed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: brandRed.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.bolt, color: brandRed),
                                SizedBox(width: 8),
                                Text(
                                  "عروض 24 ساعة 🔥",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: brandRed,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: isFlashSale,
                              activeColor: brandRed,
                              onChanged: (val) {
                                setModalState(() {
                                  isFlashSale = val;
                                  if (val) {
                                    // نشر مباشر افتراضياً: 24 ساعة من الآن
                                    isScheduled = false;
                                    flashSaleStart = null;
                                    flashSaleExpiry = DateTime.now().add(
                                      const Duration(hours: 24),
                                    );
                                  } else {
                                    flashSaleStart = null;
                                    flashSaleExpiry = null;
                                    isScheduled = false;
                                  }
                                });
                              },
                            ),
                          ],
                        ),

                        if (isFlashSale) ...[
                          const Divider(),

                          // ===== خيار النشر المباشر =====
                          RadioListTile<bool>(
                            value: false,
                            groupValue: isScheduled,
                            activeColor: brandRed,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'نشر مباشر',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'يبدأ العرض الآن وينتهي بعد 24 ساعة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                              ),
                            ),
                            onChanged: (v) {
                              setModalState(() {
                                isScheduled = false;
                                flashSaleStart = null;
                                flashSaleExpiry = DateTime.now().add(
                                  const Duration(hours: 24),
                                );
                              });
                            },
                          ),

                          // ===== خيار الجدولة =====
                          RadioListTile<bool>(
                            value: true,
                            groupValue: isScheduled,
                            activeColor: brandRed,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'جدولة لموعد محدد',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'يُخفى العرض حتى موعده، ثم يظهر 24 ساعة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                              ),
                            ),
                            onChanged: (v) {
                              setModalState(() {
                                isScheduled = true;
                                flashSaleStart ??= DateTime.now().add(
                                  const Duration(days: 1),
                                );
                                flashSaleExpiry = flashSaleStart!.add(
                                  const Duration(hours: 24),
                                );
                              });
                            },
                          ),

                          // ===== منتقي موعد البدء =====
                          if (isScheduled) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      flashSaleStart ??
                                      DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 60),
                                  ),
                                );
                                if (picked == null) return;

                                if (!context.mounted) return;
                                final TimeOfDay? time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    flashSaleStart ?? DateTime.now(),
                                  ),
                                );
                                if (time == null) return;

                                setModalState(() {
                                  flashSaleStart = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                  // الانتهاء دائماً بعد 24 ساعة من البدء
                                  flashSaleExpiry = flashSaleStart!.add(
                                    const Duration(hours: 24),
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: brandRed.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.event_available_rounded,
                                      color: brandRed,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Text(
                                        flashSaleStart == null
                                            ? 'اختر موعد بدء العرض'
                                            : 'يبدأ ${intl.DateFormat('yyyy/MM/dd — HH:mm').format(flashSaleStart!)}',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.edit_calendar,
                                      size: 17,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // ===== ملخّص المدة =====
                          if (flashSaleExpiry != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 15,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ينتهي ${intl.DateFormat('yyyy/MM/dd — HH:mm').format(flashSaleExpiry!)}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        "نوع الخصم: ",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("مبلغ ثابت"),
                        selected: discountType == "fixed",
                        onSelected: (val) => setModalState(() {
                          discountType = "fixed";
                          discountInputController.clear();
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("نسبة %"),
                        selected: discountType == "percent",
                        onSelected: (val) =>
                            setModalState(() => discountType = "percent"),
                      ),
                      if (discountType == "percent") ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: discountInputController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                setModalState(() => calculateNewPrice()),
                            decoration: InputDecoration(
                              hintText: "%",
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInput(
                          oldPriceController,
                          "السعر الأصلي",
                          Icons.history,
                          isDark,
                          showError,
                          isNumber: true,
                          onChanged: (_) => calculateNewPrice(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInput(
                          priceController,
                          "السعر الجديد",
                          Icons.auto_fix_high,
                          isDark,
                          showError,
                          isNumber: true,
                          readOnly: discountType == "percent",
                        ),
                      ),
                    ],
                  ),
                  _buildInput(
                    urlController,
                    "رابط العرض (متجر خارجي)",
                    Icons.link,
                    isDark,
                    showError,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  priceController.text.isEmpty ||
                                  selectedCategoryId == null ||
                                  storeCategoryValue == null ||
                                  (slotFiles[0] == null &&
                                      slotUrls[0] == null)) {
                                setModalState(() => showError = true);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "يرجى إكمال البيانات ورفع الصورة الرئيسية",
                                    ),
                                    backgroundColor: brandRed,
                                  ),
                                );
                                return;
                              }

                              // ✅ المنصة للعروض فقط — لا عرض بلا تخفيض
                              final oldP = double.tryParse(
                                oldPriceController.text,
                              );
                              final newP = double.tryParse(
                                priceController.text,
                              );

                              if (oldP == null || oldP <= 0) {
                                setModalState(() => showError = true);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "يرجى إدخال السعر الأصلي قبل التخفيض",
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: brandRed,
                                  ),
                                );
                                return;
                              }

                              if (newP == null || newP <= 0 || newP >= oldP) {
                                setModalState(() => showError = true);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "السعر بعد التخفيض يجب أن يكون أقل من السعر الأصلي",
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: brandRed,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);

                              // رفع الخانات الأربع بالترتيب — الأولى رئيسية
                              final List<String> resolved = [];
                              bool uploadFailed = false;

                              for (var i = 0; i < 4; i++) {
                                if (slotFiles[i] != null) {
                                  final url = await _uploadImage(slotFiles[i]!);
                                  if (url == null) {
                                    uploadFailed = true;
                                    break;
                                  }
                                  resolved.add(url);
                                } else if (slotUrls[i] != null) {
                                  resolved.add(slotUrls[i]!);
                                }
                              }

                              if (uploadFailed || resolved.isEmpty) {
                                setModalState(() => isSaving = false);
                                return;
                              }

                              final String finalUrl = resolved.first;
                              final List<String> finalExtras = resolved
                                  .skip(1)
                                  .toList();
                              await _upsertProduct(
                                ProductItem(
                                  id: productToEdit?.id ?? "",
                                  name: nameController.text,
                                  categoryId: selectedCategoryId!,
                                  subCategoryId: selectedSubCategoryId,
                                  storeCategory: storeCategoryValue ?? "عام",
                                  price:
                                      double.tryParse(priceController.text) ??
                                      0,
                                  oldPrice: double.tryParse(
                                    oldPriceController.text,
                                  ),
                                  description: descController.text,
                                  isAvailable:
                                      productToEdit?.isAvailable ?? true,
                                  imageUrl: finalUrl,
                                  imagesUrl: finalExtras,
                                  productUrl: urlController.text,
                                  isFlashSale: isFlashSale,
                                  flashSaleExpiry: flashSaleExpiry,
                                  flashSaleStart: flashSaleStart,
                                ),
                                isUpdate: productToEdit != null,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "حفظ العرض",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputMultiline(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool isDark,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      maxLines: 5,
      minLines: 3,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        height: 1.6,
      ),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(icon, color: brandRed, size: 20),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: brandRed, width: 2),
        ),
      ),
    ),
  );
  Widget _buildInput(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool isDark,
    bool showError, {
    bool isNumber = false,
    bool readOnly = false,
    Function(String)? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      onChanged: onChanged,
      readOnly: readOnly,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        fillColor: readOnly ? Colors.grey.withValues(alpha: 0.1) : null,
        filled: readOnly,
        prefixIcon: Icon(icon, color: brandRed, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: (showError && ctrl.text.isEmpty)
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
        focusedBorder: (showError && ctrl.text.isEmpty)
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: brandRed, width: 2),
              ),
      ),
    ),
  );
}

class CategorySelectionPage extends StatefulWidget {
  final List<CategoryItem> mainCategories;
  final List<CategoryItem> allSubCategories;

  const CategorySelectionPage({
    super.key,
    required this.mainCategories,
    required this.allSubCategories,
  });

  @override
  State<CategorySelectionPage> createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<CategorySelectionPage> {
  String? selectedStoreId;

  @override
  Widget build(BuildContext context) {
    final List<CategoryItem> currentList;
    if (selectedStoreId == null) {
      currentList = widget.mainCategories;
    } else {
      currentList = widget.allSubCategories
          .where(
            (s) => s.storeCategoryId.toString() == selectedStoreId.toString(),
          )
          .toList();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            selectedStoreId == null ? "اختر قسم المتجر" : "اختر القسم الفرعي",
          ),
          backgroundColor: brandRed,
          leading: selectedStoreId != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => selectedStoreId = null),
                )
              : null,
        ),
        body: ListView.separated(
          itemCount: currentList.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final item = currentList[i];
            return ListTile(
              title: Text(
                item.name,
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              trailing: Icon(
                selectedStoreId == null ? Icons.arrow_forward_ios : Icons.check,
                size: 16,
              ),
              onTap: () {
                if (selectedStoreId == null) {
                  setState(() {
                    selectedStoreId = item.id;
                  });
                } else {
                  Navigator.pop(context, item);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
