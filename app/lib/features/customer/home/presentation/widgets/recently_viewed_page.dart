import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_market_core/red_market_core.dart';
import '../widgets/product_card.dart';

class RecentlyViewedPage extends StatefulWidget {
  const RecentlyViewedPage({super.key});

  @override
  State<RecentlyViewedPage> createState() => _RecentlyViewedPageState();
}

class _RecentlyViewedPageState extends State<RecentlyViewedPage> {
  final supabase = Supabase.instance.client;
  List<ProductModel> _recentProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentlyViewed();
  }

  Future<void> _fetchRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString('recently_viewed_data') ?? '[]';

      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));

      final now = DateTime.now();

      // ✅ فلترة العروض التي مضى عليها أكثر من 5 أيام
      items = items.where((e) {
        final visitedAt = DateTime.tryParse(e['visited_at'] ?? '');
        return visitedAt != null && now.difference(visitedAt).inDays < 5;
      }).toList();

      // ✅ حفظ القائمة بعد الفلترة
      await prefs.setString('recently_viewed_data', jsonEncode(items));

      final List<String> recentIds =
          items.map((e) => e['id'] as String).toList();

      if (recentIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await supabase
          .from('products')
          .select()
          .filter('id', 'in', recentIds)
          .limit(20);

      if (mounted) {
        setState(() {
          // ✅ ترتيب العروض حسب ترتيب الزيارة (الأحدث أولاً)
          final List<ProductModel> products =
              (data as List).map((p) => ProductModel.fromJson(p)).toList();
          final byId = {for (final p in products) p.id: p};
          _recentProducts = recentIds
              .map((id) => byId[id])
              .whereType<ProductModel>()
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: const Text("قمت بزيارتها مؤخراً",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32027)))
            : _recentProducts.isEmpty
                ? const Center(
                    child: Text("لم تقم بزيارة أي عروض بعد",
                        style: TextStyle(fontFamily: 'Cairo')))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _recentProducts.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: _recentProducts[index]),
                  ),
      ),
    );
  }
}
