import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

final recentlyViewedProvider = StateProvider<List<ProductModel>>((ref) => []);

class RecentlyViewedNotifier {
  static const String _key = 'recently_viewed';

  static Future<void> loadRecentlyViewed(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> ids = prefs.getStringList(_key) ?? [];

    if (ids.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final data =
          await supabase.from('products').select().filter('id', 'in', ids);

      final products =
          (data as List).map((p) => ProductModel.fromJson(p)).toList();

      // خريطة بالمعرّفات لتفادي البحث المتكرر داخل الحلقة
      final byId = {for (final p in products) p.id.toString(): p};
      final sortedProducts =
          ids.map((id) => byId[id]).whereType<ProductModel>().toList();

      ref.read(recentlyViewedProvider.notifier).state = sortedProducts;
    } catch (e) {
      debugPrint("Error loading recently viewed: $e");
    }
  }

  /// ✅ إضافة عرض — يحفظ في السوبابيس إذا مسجل دخول وفي SharedPreferences إذا لا
  static Future<void> addProduct(WidgetRef ref, ProductModel product) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    // ✅ حفظ في السوبابيس إذا مسجل دخول
    if (userId != null) {
      try {
        await supabase.from('user_recently_viewed').upsert({
          'user_id': userId,
          'product_id': product.id,
          'visited_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,product_id');

        // ✅ حذف القديم إذا تجاوز 20 عرض
        final all = await supabase
            .from('user_recently_viewed')
            .select('id, visited_at')
            .eq('user_id', userId)
            .order('visited_at', ascending: false);

        if ((all as List).length > 20) {
          final toDelete = all.sublist(20);
          for (final row in toDelete) {
            await supabase
                .from('user_recently_viewed')
                .delete()
                .eq('id', row['id']);
          }
        }
      } catch (e) {
        debugPrint("Error saving to supabase: $e");
      }
    }

    // ✅ حفظ في SharedPreferences للزوار
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = prefs.getStringList(_key) ?? [];
    ids.remove(product.id.toString());
    ids.insert(0, product.id.toString());
    if (ids.length > 20) ids = ids.sublist(0, 20);
    await prefs.setStringList(_key, ids);

    // ✅ تحديث الـ Provider فوراً
    final currentList = ref.read(recentlyViewedProvider);
    final updatedList = [
      product,
      ...currentList.where((p) => p.id != product.id)
    ].take(20).toList();
    ref.read(recentlyViewedProvider.notifier).state = updatedList;
  }
}
