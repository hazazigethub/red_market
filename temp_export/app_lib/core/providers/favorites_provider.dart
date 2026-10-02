import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ هذا هو المتغير الذي يبحث عنه الكود (favoritesProvider)
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({});

  final supabase = Supabase.instance.client;

  // 1. جلب المفضلة
  Future<void> fetchFavorites() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('favorites')
          .select('product_id')
          .eq('user_id', userId);

      final favIds =
          (response as List).map((e) => e['product_id'] as String).toSet();
      state = favIds;
    } catch (e) {
      // تجاهل الأخطاء البسيطة
    }
  }

  // 2. التبديل (إضافة/حذف)
  Future<void> toggleFavorite(String productId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (state.contains(productId)) {
      state = {...state}..remove(productId);
      try {
        await supabase.from('favorites').delete().match({
          'user_id': userId,
          'product_id': productId,
        });
      } catch (e) {
        state = {...state}..add(productId);
      }
    } else {
      state = {...state}..add(productId);
      try {
        await supabase.from('favorites').insert({
          'user_id': userId,
          'product_id': productId,
        });
      } catch (e) {
        state = {...state}..remove(productId);
      }
    }
  }
}
