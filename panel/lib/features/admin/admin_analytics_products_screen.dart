import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// يجلب كل الصفوف على دفعات — يتجاوز حد الألف الافتراضي في Supabase
Future<List<dynamic>> fetchAllRows(String table, {String columns = '*'}) async {
  final supabase = Supabase.instance.client;
  final List<dynamic> out = [];
  const int pageSize = 1000;
  int from = 0;

  while (true) {
    final page = await supabase
        .from(table)
        .select(columns)
        .range(from, from + pageSize - 1);
    final rows = page as List;
    out.addAll(rows);
    if (rows.length < pageSize) break;
    from += pageSize;
    if (from > 50000) break;
  }
  return out;
}

class AdminAnalyticsProductsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsProductsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsProductsScreen> createState() =>
      _AdminAnalyticsProductsScreenState();
}

class _AdminAnalyticsProductsScreenState
    extends ConsumerState<AdminAnalyticsProductsScreen> {
  int _topVisitedCount = 5;
  int _topSearchedCount = 5;
  final TextEditingController _visitedCountController =
      TextEditingController(text: '5');
  final TextEditingController _searchedCountController =
      TextEditingController(text: '5');

  // ✅ فلاتر زمنية منفصلة
  String _visitedFilter = 'M';
  String _searchedFilter = 'M';

  Future<Map<String, dynamic>> _fetchAdvancedStats() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

    // ✅ جلب كل العروض
    final List products = await fetchAllRows('products',
        columns:
            'id, name, image_url, category, is_available, is_banned, likes_count, created_at');

    int totalProducts = products.length;

    int newlyAdded = products.where((p) {
      DateTime createdAt = DateTime.parse(p['created_at']);
      return createdAt.isAfter(twentyFourHoursAgo);
    }).length;

    // ✅ عروض فعالة
    int activeProducts =
        products.where((p) => p['is_available'] == true).length;

    // ✅ عروض غير فعالة
    int inactiveProducts =
        products.where((p) => p['is_available'] == false).length;

    // ✅ عروض محظورة
    int bannedProducts = products.where((p) => p['is_banned'] == true).length;

    // ✅ الأكثر زيارة = الأكثر إعجاباً مع فلتر زمني
    DateTime visitedFrom = _getFromDate(_visitedFilter);
    var topVisited = products.where((p) {
      DateTime createdAt = DateTime.parse(p['created_at']);
      return createdAt.isAfter(visitedFrom);
    }).toList();
    topVisited.sort(
        (a, b) => (b['likes_count'] ?? 0).compareTo(a['likes_count'] ?? 0));

    // ✅ فلتر الزمن للأكثر إضافة للمفضلة (بديل الأكثر بحثاً)
    DateTime searchedFrom = _getFromDate(_searchedFilter);
    var topSearched = products.where((p) {
      DateTime createdAt = DateTime.parse(p['created_at']);
      return createdAt.isAfter(searchedFrom);
    }).toList();
    topSearched.sort(
        (a, b) => (b['likes_count'] ?? 0).compareTo(a['likes_count'] ?? 0));

    return {
      'total': totalProducts,
      'newlyAdded': newlyAdded,
      'activeProducts': activeProducts,
      'inactiveProducts': inactiveProducts,
      'bannedProducts': bannedProducts,
      'topVisited': topVisited.take(_topVisitedCount).toList(),
      'topSearched': topSearched.take(_topSearchedCount).toList(),
    };
  }

  DateTime _getFromDate(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'D':
        return now.subtract(const Duration(days: 1));
      case 'M':
        return now.subtract(const Duration(days: 30));
      case 'Y':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                body: FutureBuilder<Map<String, dynamic>>(
          future: _fetchAdvancedStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return Center(child: Text("خطأ: ${snapshot.error}"));
            }

            final data = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderStat("إجمالي عروض المنصة", "${data['total']}",
                      Colors.orange, Icons.inventory_2),
                  const SizedBox(height: 20),
                  const Text("تحليل المخزون",
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 12),

                  // ✅ الكروت الأربعة
                  Row(
                    children: [
                      _buildInfoCard(
                          context,
                          "أضيفت (24س)",
                          "${data['newlyAdded']}",
                          Colors.blue,
                          Icons.add_business_outlined),
                      const SizedBox(width: 10),
                      _buildInfoCard(
                          context,
                          "عروض فعالة",
                          "${data['activeProducts']}",
                          Colors.green,
                          Icons.check_circle_outline),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // ✅ كرت عروض غير فعالة
                      _buildInfoCard(
                          context,
                          "غير فعالة",
                          "${data['inactiveProducts']}",
                          Colors.orange,
                          Icons.remove_circle_outline),
                      const SizedBox(width: 10),
                      // ✅ كرت عروض محظورة
                      _buildInfoCard(
                          context,
                          "محظورة",
                          "${data['bannedProducts']}",
                          Colors.red,
                          Icons.block_outlined),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ✅ الأكثر إضافة للمفضلة مع فلتر زمني
                  _buildSectionHeaderWithFilter(
                    "الأكثر إضافة للمفضلة",
                    _searchedCountController,
                    _searchedFilter,
                    (val) => setState(() {
                      _topSearchedCount = int.tryParse(val) ?? 5;
                    }),
                    (filter) => setState(() {
                      _searchedFilter = filter;
                    }),
                  ),
                  const SizedBox(height: 10),
                  ...data['topSearched']
                      .map((p) => _buildProductRow(
                          context, p, Icons.favorite, Colors.pink))
                      .toList(),

                  const SizedBox(height: 30),

                  // ✅ الأكثر زيارة مع فلتر زمني
                  _buildSectionHeaderWithFilter(
                    "الأكثر زيارة",
                    _visitedCountController,
                    _visitedFilter,
                    (val) => setState(() {
                      _topVisitedCount = int.tryParse(val) ?? 5;
                    }),
                    (filter) => setState(() {
                      _visitedFilter = filter;
                    }),
                  ),
                  const SizedBox(height: 10),
                  ...data['topVisited']
                      .map((p) => _buildProductRow(
                          context, p, Icons.visibility, Colors.purple))
                      .toList(),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderStat(
      String title, String value, Color iconColor, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 45),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value,
      Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ✅ عنوان القسم مع فلتر D/M/Y وخانة العدد
  Widget _buildSectionHeaderWithFilter(
    String title,
    TextEditingController controller,
    String activeFilter,
    Function(String) onCountSubmitted,
    Function(String) onFilterChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: 70,
              height: 32,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "العدد",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: onCountSubmitted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ✅ أزرار D/M/Y
        Row(
          children: ['D', 'M', 'Y'].map((filter) {
            final bool isActive = activeFilter == filter;
            final String label = filter == 'D'
                ? 'يوم'
                : filter == 'M'
                    ? 'شهر'
                    : 'سنة';
            return GestureDetector(
              onTap: () => onFilterChanged(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFD32027) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFD32027)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProductRow(
      BuildContext context, dynamic p, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade100,
            backgroundImage:
                p['image_url'] != null ? NetworkImage(p['image_url']) : null,
            child: p['image_url'] == null
                ? const Icon(Icons.image, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] ?? 'عرض',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(p['category'] ?? 'غير مصنف',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            children: [
              Icon(icon, color: color, size: 14),
              Text(
                "${p['likes_count'] ?? 0}",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
