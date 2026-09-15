import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isDeleting = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  late Future<List<Map<String, dynamic>>> _bannersStream;

  @override
  void initState() {
    super.initState();
    _bannersStream = supabase
        .from('banners')
        .select()
        .order('created_at', ascending: false)
        .then((v) => List<Map<String, dynamic>>.from(v));

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadBanners() async {
    final v = await supabase
        .from('banners')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(v);
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final mime = imageFile.mimeType ?? 'image/jpeg';
      final fileExt = mime.split('/').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'banners/$fileName';
      final bytes = await imageFile.readAsBytes();
      await supabase.storage.from('banners_bucket').uploadBinary(
            path,
            bytes,
            fileOptions:
                FileOptions(upsert: true, contentType: mime),
          );
      return supabase.storage.from('banners_bucket').getPublicUrl(path);
    } catch (e) {
      debugPrint("خطأ رفع الصورة: $e");
      return null;
    }
  }

  Future<void> _saveBanner({
    String? id,
    required String bannerName,
    required String? merchantId,
    String? productId,
    String? categoryId,
    required String imageUrl,
    required bool isPermanent,
    required String bannerType,
    required bool isActive,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final data = {
      'name': bannerName,
      'merchant_id': merchantId,
      'product_id': productId,
      'category_id': categoryId,
      'image_url': imageUrl,
      'is_permanent': isPermanent,
      'banner_type': bannerType,
      'start_date': isPermanent ? null : startDate?.toIso8601String(),
      'end_date': isPermanent ? null : endDate?.toIso8601String(),
      'is_active': isActive,
    };

    try {
      if (id == null) {
        await supabase.from('banners').insert(data);
      } else {
        await supabase.from('banners').update(data).eq('id', id);
      }
      if (mounted) setState(() { _bannersStream = _loadBanners(); });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ البيانات بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("خطأ في الحفظ: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف البنر", style: TextStyle(fontFamily: 'Cairo')),
        content: const Text("هل أنت متأكد من حذف هذا البنر نهائياً؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isDeleting = true);
      try {
        await supabase.from('banners').delete().eq('id', id);
        if (mounted) setState(() { _bannersStream = _loadBanners(); });
        if (mounted) {
          if (Navigator.canPop(context)) Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم الحذف بنجاح'),
                backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        debugPrint("خطأ أثناء الحذف: $e");
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  Widget _buildStatusBadge(Map<String, dynamic> banner) {
    final bool isActive = banner['is_active'] ?? true;
    final bool isPermanent = banner['is_permanent'] ?? true;
    final DateTime? endDate =
        banner['end_date'] != null ? DateTime.parse(banner['end_date']) : null;
    final DateTime now = DateTime.now();

    String label = "فعال";
    Color color = Colors.green;

    if (!isActive) {
      label = "غير فعال";
      color = Colors.grey;
    } else if (!isPermanent && endDate != null && endDate.isBefore(now)) {
      label = "منتهي";
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo'),
      ),
    );
  }

  // ✅ عرض معلومات البنر
  void _showBannerInfo(BuildContext context, Map<String, dynamic> banner) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Text(banner['name'] ?? 'بنر',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (banner['merchant_id'] != null)
                _infoRow(Icons.storefront, "متجر مرتبط",
                    banner['merchant_id'].toString()),
              if (banner['product_id'] != null)
                _infoRow(Icons.shopping_bag, "عرض مرتبط",
                    banner['product_id'].toString()),
              if (banner['category_id'] != null)
                _infoRow(Icons.category, "تصنيف مرتبط",
                    banner['category_id'].toString()),
              _infoRow(Icons.view_compact, "النوع",
                  banner['banner_type'] == 'wide' ? "عريض" : "صغير"),
              _infoRow(Icons.circle, "الحالة",
                  (banner['is_active'] ?? true) ? "فعال" : "غير فعال"),
              _infoRow(Icons.autorenew, "نوع العرض",
                  (banner['is_permanent'] ?? true) ? "دائم" : "مؤقت"),
              if (banner['is_permanent'] == false) ...[
                if (banner['start_date'] != null)
                  _infoRow(
                      Icons.calendar_today,
                      "تاريخ البداية",
                      DateTime.parse(banner['start_date'])
                          .toString()
                          .substring(0, 10)),
                if (banner['end_date'] != null)
                  _infoRow(
                      Icons.event,
                      "تاريخ الانتهاء",
                      DateTime.parse(banner['end_date'])
                          .toString()
                          .substring(0, 10)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text("إغلاق", style: TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFD32027)),
          const SizedBox(width: 8),
          Text("$label: ",
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ✅ كرت البنر مع اسم + معلومات
  Widget _buildBannerCard(
      Map<String, dynamic> banner, bool isWide, Color brandRed) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Stack(
        children: [
          Image.network(
            banner['image_url'],
            height: isWide ? 160 : 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          // ✅ اسم البنر + حالته في الأسفل
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      banner['name'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(banner),
                ],
              ),
            ),
          ),
          // ✅ زر التعديل
          Positioned(
            top: 8,
            left: 8,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.edit, color: brandRed, size: 20),
                onPressed: () =>
                    _showAddBannerSheet(brandRed, existingBanner: banner),
              ),
            ),
          ),
          // ✅ زر المعلومات
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.info_outline,
                    color: Colors.blueGrey, size: 20),
                onPressed: () => _showBannerInfo(context, banner),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionIcon(IconData icon, String typeQuery, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchController.text = typeQuery;
        });
      },
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFEDEFF3))),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "بحث عن بنر",
                          hintStyle: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 19, color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: const BorderSide(
                                  color: Color(0xFFEDEFF3))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: const BorderSide(
                                  color: brandRed, width: 1.4)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionIcon(
                      Icons.view_headline, "wide", Colors.blueGrey),
                  const SizedBox(width: 5),
                  _buildQuickActionIcon(
                      Icons.view_module, "small", Colors.blueGrey),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAddBannerSheet(brandRed),
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                          color: brandRed,
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _bannersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: brandRed));
                  }
                  final banners = snapshot.data ?? [];

                  final filtered = banners.where((b) {
                    if (_searchQuery.isEmpty) return true;
                    String name = (b['name'] ?? "").toString().toLowerCase();
                    String type =
                        (b['banner_type'] ?? "").toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        type.contains(_searchQuery);
                  }).toList();

                  if (banners.isEmpty) {
                    return const Center(
                        child: Text("لا توجد بنرات",
                            style: TextStyle(fontFamily: 'Cairo')));
                  }

                  final wideBanners = filtered
                      .where((b) => b['banner_type'] == 'wide')
                      .toList();
                  final smallBanners = filtered
                      .where((b) => b['banner_type'] == 'small')
                      .toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1050),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ===== البنرات العريضة — اثنتان في الصف =====
                        if (wideBanners.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, c) {
                              const gap = 12.0;
                              final cols = c.maxWidth < 700 ? 1 : 2;
                              final w =
                                  (c.maxWidth - gap * (cols - 1)) / cols;

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: wideBanners
                                    .map((banner) => SizedBox(
                                          width: w,
                                          child: _buildBannerCard(
                                              banner, true, brandRed),
                                        ))
                                    .toList(),
                              );
                            },
                          ),

                        if (wideBanners.isNotEmpty &&
                            smallBanners.isNotEmpty)
                          const SizedBox(height: 12),

                        // ===== البنرات الصغيرة — أربع في الصف =====
                        if (smallBanners.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, c) {
                              const gap = 12.0;
                              int cols = 4;
                              if (c.maxWidth < 500) {
                                cols = 2;
                              } else if (c.maxWidth < 780) {
                                cols = 3;
                              }
                              final w =
                                  (c.maxWidth - gap * (cols - 1)) / cols;

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: smallBanners
                                    .map((banner) => SizedBox(
                                          width: w,
                                          child: _buildBannerCard(
                                              banner, false, brandRed),
                                        ))
                                    .toList(),
                              );
                            },
                          ),

                        const SizedBox(height: 20),
                      ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBannerSheet(Color brandRed,
      {Map<String, dynamic>? existingBanner}) {
    XFile? selectedImage;
    // ✅ تحديث الاسم من البيانات الموجودة
    final nameController =
        TextEditingController(text: existingBanner?['name'] ?? "");

    String? selectedProductCategoryId = existingBanner?['category_id'];
    String? selectedMerchantId = existingBanner?['merchant_id'];
    String? selectedProductId = existingBanner?['product_id'];
    String merchantSearchText = "";
    bool isMerchantFixed = selectedMerchantId != null;

    bool isPermanent = existingBanner?['is_permanent'] ?? true;
    bool isActive = existingBanner?['is_active'] ?? true;
    String bannerType = existingBanner?['banner_type'] ?? 'wide';
    DateTime? start = existingBanner?['start_date'] != null
        ? DateTime.parse(existingBanner!['start_date'])
        : null;
    DateTime? end = existingBanner?['end_date'] != null
        ? DateTime.parse(existingBanner!['end_date'])
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        existingBanner == null
                            ? "إضافة بنر جديد"
                            : "تعديل البنر",
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    if (existingBanner != null)
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteBanner(existingBanner['id'])),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      hintText: "اسم البنر الإعلاني",
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(15)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: brandRed),
                          borderRadius: BorderRadius.circular(15))),
                ),
                const SizedBox(height: 15),

                // ✅ الارتباط بمتجر — مستقل عن التصنيف
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("الارتباط بمتجر (اختياري):",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (!isMerchantFixed) ...[
                      TextField(
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        onChanged: (val) =>
                            setSheetState(() => merchantSearchText = val),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: "ابحث عن متجر...",
                          prefixIcon: const Icon(Icons.search),
                          enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(15)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: brandRed),
                              borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                      if (merchantSearchText.isNotEmpty)
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.from('merchants').select(),
                          builder: (context, snapshot) {
                            final list = snapshot.data ?? [];
                            final filtered = list
                                .where((m) => (m['store_name'] ?? "")
                                    .toString()
                                    .toLowerCase()
                                    .contains(merchantSearchText.toLowerCase()))
                                .toList();
                            return Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(15)),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) => ListTile(
                                  title: Text(filtered[i]['store_name'] ?? "",
                                      style: const TextStyle(
                                          fontFamily: 'Cairo', fontSize: 13)),
                                  onTap: () => setSheetState(() {
                                    selectedMerchantId =
                                        filtered[i]['id'].toString();
                                    isMerchantFixed = true;
                                    merchantSearchText = "";
                                    // ✅ لا نصفر التصنيف
                                  }),
                                ),
                              ),
                            );
                          },
                        ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, color: Colors.green),
                            const SizedBox(width: 10),
                            const Text("متجر محدد بنجاح",
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            TextButton(
                                onPressed: () => setSheetState(() {
                                      isMerchantFixed = false;
                                      selectedMerchantId = null;
                                      selectedProductId = null;
                                      // ✅ لا نصفر التصنيف
                                    }),
                                child: const Text("تغيير"))
                          ],
                        ),
                      ),
                  ],
                ),

                // ✅ اختيار العرض
                if (selectedMerchantId != null)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: supabase
                        .from('products')
                        .select()
                        .eq('merchant_id', selectedMerchantId!),
                    builder: (context, snapshot) {
                      final products = snapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 15),
                          const Text("اختر العرض (اختياري):",
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(15),
                                border:
                                    Border.all(color: Colors.grey.shade200)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedProductId,
                                hint: const Text("ربط بعرض محدد...",
                                    style: TextStyle(
                                        fontFamily: 'Cairo', fontSize: 13)),
                                items: products
                                    .map((p) => DropdownMenuItem(
                                          value: p['id'].toString(),
                                          child: Text(p['name'] ?? "",
                                              style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (val) => setSheetState(
                                    () => selectedProductId = val),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                // ✅ الارتباط بتصنيف — مستقل عن المتجر
                const SizedBox(height: 15),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text("الارتباط بتصنيف (اختياري):",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final selected = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (BuildContext context) {
                        String dialogSearchText = "";
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            return Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: const BorderSide(
                                      color: Colors.red, width: 3),
                                ),
                                title: const Text("ابحث عن تصنيف",
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 350,
                                  child: Column(
                                    children: [
                                      TextField(
                                        style: const TextStyle(
                                            fontFamily: 'Cairo', fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: "اكتب اسم التصنيف...",
                                          prefixIcon: const Icon(Icons.search,
                                              size: 20),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade200),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            dialogSearchText = val;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: FutureBuilder<
                                            List<Map<String, dynamic>>>(
                                          future: supabase
                                              .from('product_categories')
                                              .select(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            }
                                            final list = snapshot.data ?? [];
                                            final filtered = list
                                                .where((c) => (c['name'] ?? "")
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains(dialogSearchText
                                                        .toLowerCase()))
                                                .toList();

                                            if (filtered.isEmpty) {
                                              return const Center(
                                                  child: Text("لا توجد نتائج",
                                                      style: TextStyle(
                                                          fontFamily:
                                                              'Cairo')));
                                            }

                                            return ListView.separated(
                                              itemCount: filtered.length,
                                              separatorBuilder:
                                                  (context, index) => Divider(
                                                      color:
                                                          Colors.grey.shade100),
                                              itemBuilder: (context, index) {
                                                return ListTile(
                                                  title: Text(
                                                      filtered[index]['name'] ??
                                                          "",
                                                      style: const TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 13)),
                                                  onTap: () {
                                                    Navigator.pop(context,
                                                        filtered[index]);
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );

                    if (selected != null) {
                      setSheetState(() {
                        selectedProductCategoryId = selected['id'].toString();
                        // ✅ لا نصفر المتجر عند اختيار تصنيف
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 15),
                    decoration: BoxDecoration(
                        color: selectedProductCategoryId != null
                            ? Colors.green.withValues(alpha: 0.05)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: selectedProductCategoryId != null
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.grey.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                            selectedProductCategoryId != null
                                ? Icons.check_circle
                                : Icons.search,
                            color: selectedProductCategoryId != null
                                ? Colors.green
                                : Colors.grey,
                            size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedProductCategoryId != null
                                ? "تم تحديد التصنيف (اضغط لتغييره)"
                                : "اضغط للبحث واختيار تصنيف...",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: selectedProductCategoryId != null
                                    ? Colors.green
                                    : Colors.black87,
                                fontWeight: selectedProductCategoryId != null
                                    ? FontWeight.bold
                                    : FontWeight.normal),
                          ),
                        ),
                        if (selectedProductCategoryId != null)
                          GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedProductCategoryId = null;
                              });
                            },
                            child: const Icon(Icons.close,
                                color: Colors.red, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // ✅ قسم التواريخ
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("بنر دائم",
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold)),
                          Switch(
                            value: isPermanent,
                            activeColor: brandRed,
                            onChanged: (val) =>
                                setSheetState(() => isPermanent = val),
                          ),
                        ],
                      ),
                      if (!isPermanent) ...[
                        const Divider(),
                        // تاريخ البداية
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: start ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setSheetState(() => start = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: Color(0xFFD32027), size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  start == null
                                      ? "تاريخ بداية الظهور"
                                      : "من: ${start!.day}/${start!.month}/${start!.year}",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      color: start == null
                                          ? Colors.grey
                                          : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // تاريخ النهاية
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: end ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setSheetState(() => end = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event,
                                    color: Color(0xFFD32027), size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  end == null
                                      ? "تاريخ انتهاء الظهور"
                                      : "إلى: ${end!.day}/${end!.month}/${end!.year}",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      color: end == null
                                          ? Colors.grey
                                          : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("نوع البنر:",
                        style: TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    Radio<String>(
                        value: 'wide',
                        groupValue: bannerType,
                        activeColor: brandRed,
                        onChanged: (val) =>
                            setSheetState(() => bannerType = val!)),
                    const Text("عريض", style: TextStyle(fontFamily: 'Cairo')),
                    const SizedBox(width: 10),
                    Radio<String>(
                        value: 'small',
                        groupValue: bannerType,
                        activeColor: brandRed,
                        onChanged: (val) =>
                            setSheetState(() => bannerType = val!)),
                    const Text("صغير", style: TextStyle(fontFamily: 'Cairo')),
                  ],
                ),
                const Divider(),
                GestureDetector(
                  onTap: () async {
                    final img =
                        await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) setSheetState(() => selectedImage = img);
                  },
                  child: Container(
                    height: bannerType == 'wide' ? 140 : 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? Image.network(selectedImage!.path,
                                    fit: BoxFit.cover)
                                : Image.file(File(selectedImage!.path),
                                    fit: BoxFit.cover))
                        : (existingBanner != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                    existingBanner['image_url'],
                                    fit: BoxFit.cover))
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      size: 30, color: Colors.grey),
                                  Text("اختر صورة",
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Colors.grey))
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (nameController.text.isEmpty ||
                                (selectedImage == null &&
                                    existingBanner == null)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("يرجى إدخال الاسم والصورة"),
                                    backgroundColor: Colors.red),
                              );
                              return;
                            }

                            setSheetState(() => _isSaving = true);
                            String? uploadedUrl = existingBanner?['image_url'];

                            if (selectedImage != null) {
                              uploadedUrl = await _uploadImage(selectedImage!);
                            }

                            if (uploadedUrl != null) {
                              await _saveBanner(
                                id: existingBanner?['id'],
                                bannerName: nameController.text,
                                merchantId: selectedMerchantId,
                                productId: selectedProductId,
                                categoryId: selectedProductCategoryId,
                                imageUrl: uploadedUrl,
                                isPermanent: isPermanent,
                                bannerType: bannerType,
                                isActive: isActive,
                                startDate: start,
                                endDate: end,
                              );
                            } else {
                              setSheetState(() => _isSaving = false);
                            }
                          },
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("حفظ البنر",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
