import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnalyticsProductCategoriesScreen extends StatefulWidget {
  const AdminAnalyticsProductCategoriesScreen({super.key});

  @override
  State<AdminAnalyticsProductCategoriesScreen> createState() =>
      _AdminAnalyticsProductCategoriesScreenState();
}

class _AdminAnalyticsProductCategoriesScreenState
    extends State<AdminAnalyticsProductCategoriesScreen> {
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
                  hintText: "ابحث عن قسم معين...",
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
                    .stream(primaryKey: ['id']),
                builder: (context, mainSnapshot) {
                  if (mainSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: brandRed));
                  }
                  final mainCategories = mainSnapshot.data ?? [];

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase
                        .from('product_categories')
                        .stream(primaryKey: ['id']),
                    builder: (context, subSnapshot) {
                      final allSubs = subSnapshot.data ?? [];

                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: supabase
                            .from('products')
                            .stream(primaryKey: ['id']),
                        builder: (context, productSnapshot) {
                          final allProducts = productSnapshot.data ?? [];

                          final filteredMain = mainCategories
                              .where((cat) => cat['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()))
                              .toList();

                          return CustomScrollView(
                            slivers: [
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 20)),
                              // --- كروت الإحصائيات العلوية الثلاثة ---
                              SliverPadding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                sliver: SliverToBoxAdapter(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildSummaryCard(
                                          "رئيسية",
                                          "${mainCategories.length}",
                                          Colors.purple,
                                          Icons.grid_view_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildSummaryCard(
                                          "فرعية",
                                          "${allSubs.length}",
                                          Colors.blue,
                                          Icons.account_tree_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildSummaryCard(
                                          "عروض",
                                          "${allProducts.length}",
                                          Colors.orange,
                                          Icons.inventory_2_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 25)),
                              const SliverPadding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                sliver: SliverToBoxAdapter(
                                  child: Text("الأقسام الرئيسية",
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 15)),
                              if (filteredMain.isEmpty)
                                const SliverToBoxAdapter(
                                    child: Center(child: Text("لا توجد نتائج")))
                              else
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 0.8,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final mainCat = filteredMain[index];
                                        final currentSubs = allSubs
                                            .where((s) =>
                                                s['parent_id'] == mainCat['id'])
                                            .toList();

                                        return _buildCategoryCard(
                                          context: context,
                                          name: mainCat['name'] ?? '',
                                          subCountText:
                                              "${currentSubs.length} فرعي",
                                          productCount: allProducts
                                              .where((p) => currentSubs.any(
                                                  (s) =>
                                                      s['id'] ==
                                                      p['category_id']))
                                              .length,
                                          brandRed: brandRed,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SubCategoriesDetailScreen(
                                                  title: mainCat['name'] ?? '',
                                                  subs: currentSubs,
                                                  allProducts: allProducts,
                                                  brandRed: brandRed,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      childCount: filteredMain.length,
                                    ),
                                  ),
                                ),
                            ],
                          );
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
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
          ]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // توسيط عمودي
        crossAxisAlignment: CrossAxisAlignment.center, // توسيط أفقي
        children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 8),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

Widget _buildCategoryCard({
  required BuildContext context,
  required String name,
  required String subCountText,
  required int productCount,
  required Color brandRed,
  required VoidCallback onTap,
  bool showStatus = false,
  bool isVisible = true,
}) {
  return InkWell(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: brandRed.withValues(alpha: 0.1),
                  child: Icon(Icons.category, color: brandRed, size: 16)),
              if (showStatus)
                Icon(Icons.circle,
                    size: 10, color: isVisible ? Colors.green : Colors.red),
            ],
          ),
          const SizedBox(height: 6),
          Text(name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 10)),
          const SizedBox(height: 2),
          Text(subCountText,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 8, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            "$productCount",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.red,
            ),
          ),
        ],
      ),
    ),
  );
}

class SubCategoriesDetailScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> subs;
  final List<Map<String, dynamic>> allProducts;
  final Color brandRed;

  const SubCategoriesDetailScreen({
    super.key,
    required this.title,
    required this.subs,
    required this.allProducts,
    required this.brandRed,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                body: subs.isEmpty
            ? const Center(child: Text("لا توجد أقسام فرعية"))
            : GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  final sub = subs[index];
                  final pCount = allProducts
                      .where((p) => p['category_id'] == sub['id'])
                      .length;

                  return _buildCategoryCard(
                    context: context,
                    name: sub['name'] ?? '',
                    subCountText: "قسم فرعي",
                    productCount: pCount,
                    brandRed: brandRed,
                    showStatus: true,
                    isVisible: sub['is_visible'] == true,
                    onTap: () {},
                  );
                },
              ),
      ),
    );
  }
}
