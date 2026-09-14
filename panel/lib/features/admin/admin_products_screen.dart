import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminProductsScreen extends StatefulWidget {
  /// نص البحث — يأتي من الغلاف
  final String searchQuery;

  const AdminProductsScreen({super.key, this.searchQuery = ''});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  /// رابط الموقع — يُمرَّر عند البناء
  /// flutter build web --dart-define=SITE_URL=https://redmarket.sa
  static const String _siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// يفتح صفحة العرض في الموقع بتبويب جديد
  Future<void> _openProductPage(dynamic productId) async {
    final url = Uri.parse('$_siteUrl/product/$productId');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Open product error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح صفحة العرض',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  final supabase = Supabase.instance.client;

  String get _searchQuery => widget.searchQuery;

  /// التيّاران يُنشآن مرة واحدة — وإلا أُعيد الاشتراك مع كل بناء
  late final Stream<List<Map<String, dynamic>>> _productsStream =
      supabase.from('products').stream(primaryKey: ['id']);

  late final Stream<List<Map<String, dynamic>>> _reportsStream = supabase
      .from('reports')
      .stream(primaryKey: ['id']).map((items) => items
          .where((i) =>
              i['target_type'] == 'product' && i['status'] == 'pending')
          .toList());

  bool _showOnlyReported = false;
  bool _showOnlyBanned = false; // حالة جديدة لعرض المحظورات فقط

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _productsStream,
                builder: (context, productsSnapshot) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _reportsStream,
                    builder: (context, reportsSnapshot) {
                      if (productsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: brandRed));
                      }

                      final allProducts = productsSnapshot.data ?? [];
                      final allPendingReports = reportsSnapshot.data ?? [];

                      final int totalCount = allProducts.length;
                      final int activeCount = allProducts
                          .where((p) =>
                              p['is_available'] == true &&
                              (p['is_banned'] == false ||
                                  p['is_banned'] == null))
                          .length;
                      final int bannedCount = allProducts
                          .where((p) => p['is_banned'] == true)
                          .length;

                      final reportedProductIds = allPendingReports
                          .map((r) => r['target_id'].toString())
                          .toSet();

                      // فلترة البلاغات: فقط العروض التي عليها بلاغ وغير محظورة حالياً
                      final int reportedCount = allProducts
                          .where((p) =>
                              reportedProductIds.contains(p['id'].toString()) &&
                              (p['is_banned'] == false ||
                                  p['is_banned'] == null))
                          .length;

                      List<Map<String, dynamic>> displayedProducts = [];

                      if (_showOnlyReported) {
                        // عرض العروض المُبلغ عنها والتي لم تُحظر بعد
                        displayedProducts = allProducts
                            .where((p) =>
                                reportedProductIds
                                    .contains(p['id'].toString()) &&
                                (p['is_banned'] == false ||
                                    p['is_banned'] == null))
                            .toList();
                      } else if (_showOnlyBanned) {
                        // عرض العروض المحظورة فقط
                        displayedProducts = allProducts
                            .where((p) => p['is_banned'] == true)
                            .toList();
                      } else if (_searchQuery.isNotEmpty) {
                        displayedProducts = allProducts.where((p) {
                          final name =
                              p['name']?.toString().toLowerCase() ?? '';
                          return name.contains(_searchQuery.toLowerCase());
                        }).toList();
                      }

                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (!_showOnlyReported && !_showOnlyBanned) ...[
                            _buildSummaryCard("إجمالي العروض", "$totalCount",
                                Colors.purple, Icons.inventory_2),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                _statItem("النشطة", "$activeCount",
                                    Colors.green, Icons.check_circle, null),
                                const SizedBox(width: 10),
                                _statItem("المحظورة", "$bannedCount",
                                    Colors.orange, Icons.block, () {
                                  setState(() {
                                    _showOnlyBanned = true;
                                    _showOnlyReported = false;
                                  });
                                }),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _statItem("بلاغات العروض", "$reportedCount",
                                Colors.red, Icons.report_gmailerrorred, () {
                              setState(() {
                                _showOnlyReported = true;
                                _showOnlyBanned = false;
                              });
                            }),
                            const SizedBox(height: 25),
                          ],
                          if (_showOnlyReported ||
                              _showOnlyBanned ||
                              _searchQuery.isNotEmpty) ...[
                            Text(
                                _showOnlyReported
                                    ? "قائمة البلاغات النشطة"
                                    : (_showOnlyBanned
                                        ? "قائمة المحظورات"
                                        : "نتائج البحث"),
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            if (displayedProducts.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 20),
                                  child: Text("لا توجد عروض في هذه القائمة",
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Colors.grey)),
                                ),
                              ),
                            ...displayedProducts.map((p) {
                              List<String> reasons = allPendingReports
                                  .where((r) =>
                                      r['target_id'].toString() ==
                                      p['id'].toString())
                                  .map((r) =>
                                      r['reason']?.toString() ??
                                      'بدون سبب محدد')
                                  .toList();

                              return _buildProductTile(
                                  p, reasons, context, brandRed);
                            }).toList(),
                          ] else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 30),
                                child: Text(
                                    "ابحث عن عرض أو اختر تصنيفاً للمعاينة",
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.grey,
                                        fontSize: 12)),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 15),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon,
      VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: onTap != null ? color : color.withValues(alpha: 0.1),
                  width: onTap != null ? 1.5 : 1)),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: Colors.grey)),
                ],
              ),
              // تم حذف أيقونة السهم من هنا
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p, List<String> reasons,
      BuildContext context, Color brandRed) {
    bool isBanned = p['is_banned'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor)),
            child: p['image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(p['image_url'], fit: BoxFit.cover))
                : const Icon(Icons.image_not_supported_outlined,
                    color: Colors.grey),
          ),
          title: Text(
            p['name'] ?? 'عرض غير معروف',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436)),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "السعر: ${p['price']} ر.س",
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12, color: Colors.blueGrey),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  if (isBanned) {
                    // إذا كان محظوراً ونريد إلغاء الحظر
                    await supabase
                        .from('products')
                        .update({'is_banned': false}).eq('id', p['id']);

                    // تحديث كافة البلاغات المتعلقة بهذا العرض لتصبح resolved
                    await supabase
                        .from('reports')
                        .update({'status': 'resolved'})
                        .eq('target_id', p['id'])
                        .eq('target_type', 'product');
                  } else {
                    // إذا كان غير محظور ونريد حظره
                    await supabase
                        .from('products')
                        .update({'is_banned': true}).eq('id', p['id']);
                  }

                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isBanned
                              ? "تم إلغاء الحظر وإغلاق البلاغات"
                              : "تم حظر العرض بنجاح",
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        backgroundColor: isBanned ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: isBanned
                      ? Colors.green.withValues(alpha: 0.1)
                      : brandRed.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isBanned ? "إلغاء الحظر" : "حظر",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isBanned ? Colors.green : brandRed,
                  ),
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${reasons.length}",
                        style: TextStyle(
                            color: brandRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 14),
                    ],
                  ),
                ),
              ],
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  if (reasons.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.list_alt_rounded, size: 18, color: brandRed),
                        const SizedBox(width: 8),
                        const Text(
                          "تفاصيل البلاغات المُقدمة:",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Theme.of(context).dividerColor)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: Colors.black54,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openProductPage(p['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.gavel_rounded, size: 18),
                      label: const Text(
                        "مراجعة العرض واتخاذ قرار",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
