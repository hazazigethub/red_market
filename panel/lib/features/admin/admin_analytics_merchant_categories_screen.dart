import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnalyticsMerchantCategoriesScreen extends StatefulWidget {
  const AdminAnalyticsMerchantCategoriesScreen({super.key});

  @override
  State<AdminAnalyticsMerchantCategoriesScreen> createState() =>
      _AdminAnalyticsMerchantCategoriesScreenState();
}

class _AdminAnalyticsMerchantCategoriesScreenState
    extends State<AdminAnalyticsMerchantCategoriesScreen> {
  final supabase = Supabase.instance.client;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                body: Column(
          children: [
            // --- 🔍 خانة البحث ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
              decoration: const BoxDecoration(
                color: brandRed,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "ابحث عن نشاط معين...",
                  hintStyle: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: brandRed),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('store_categories')
                    .stream(primaryKey: ['id']).order('name'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: brandRed));
                  }

                  final allCategories = snapshot.data ?? [];
                  final filteredCategories = allCategories.where((cat) {
                    final name = cat['name']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

                  return FutureBuilder(
                    future: supabase
                        .from('profiles')
                        .select('id')
                        .eq('role', 'merchant')
                        .count(CountOption.exact),
                    builder: (context, totalSnapshot) {
                      final int totalMerchantsCount =
                          totalSnapshot.data?.count ?? 0;

                      return CustomScrollView(
                        slivers: [
                          // --- 📊 كروت الإحصائيات العلوية ---
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                        "إجمالي الأنشطة",
                                        "${allCategories.length}",
                                        Colors.indigo,
                                        Icons.category),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                        "إجمالي المتاجر",
                                        "$totalMerchantsCount",
                                        Colors.orange.shade800,
                                        Icons.store),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                "توزيع المتاجر حسب النشاط",
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                          ),

                          // --- 🧩 شبكة التصنيفات (3 كروت في السطر) ---
                          SliverPadding(
                            padding: const EdgeInsets.all(20),
                            sliver: filteredCategories.isEmpty
                                ? const SliverToBoxAdapter(
                                    child: Center(
                                        child: Text("لا توجد نتائج مطابقة")))
                                : SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // عدد الكروت في السطر
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.8, // ضبط ارتفاع الكرت
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final cat = filteredCategories[index];
                                        final catId = cat['id'];
                                        final catName =
                                            cat['name'] ?? 'غير محدد';

                                        return FutureBuilder(
                                          future: supabase
                                              .from('profiles')
                                              .select('id')
                                              .eq('role', 'merchant')
                                              .contains('preferred_categories',
                                                  [catId])
                                              .count(CountOption.exact),
                                          builder: (context, countSnapshot) {
                                            if (countSnapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                  child: SizedBox(
                                                      width: 10,
                                                      height: 10,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2)));
                                            }

                                            final int count =
                                                countSnapshot.data?.count ?? 0;

                                            return _buildCategoryGridTile(
                                                catName,
                                                count,
                                                totalMerchantsCount,
                                                brandRed);
                                          },
                                        );
                                      },
                                      childCount: filteredCategories.length,
                                    ),
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

  // كرت الإحصائيات العلوي
  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // كرت التصنيف الصغير (داخل الشبكة)
  Widget _buildCategoryGridTile(
      String name, int count, int total, Color brandRed) {
    double percentage = total > 0 ? (count / total) : 0.0;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor)),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront, size: 20, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            "$count متجر",
            style: TextStyle(
                color: brandRed, fontWeight: FontWeight.bold, fontSize: 10),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade100,
              color: brandRed.withValues(alpha: 0.6),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
