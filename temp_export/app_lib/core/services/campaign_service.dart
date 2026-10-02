import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة الحملة الموسمية
class CampaignService {
  CampaignService._();
  static final CampaignService instance = CampaignService._();

  final supabase = Supabase.instance.client;

  /// بذرة ثابتة للجلسة — فلا يتكرر العرض عند التمرير
  final String seed =
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  /// يمنع تكرار احتساب المشاهدة
  final Set<String> _seen = <String>{};

  /// الحملة النشطة إن وُجدت
  Future<Map<String, dynamic>?> getActive() async {
    try {
      final res = await supabase.rpc('get_active_campaign');
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('Campaign error: $e');
      return null;
    }
  }

  /// تصنيفات الحملة
  Future<List<Map<String, dynamic>>> getCategories(String campaignId) async {
    try {
      final res = await supabase.rpc('get_campaign_categories',
          params: {'p_campaign_id': campaignId});
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Campaign categories error: $e');
      return [];
    }
  }

  /// عروض الحملة
  Future<List<Map<String, dynamic>>> getProducts({
    required String campaignId,
    String? categoryId,
    double? minDiscount,
    String sort = 'random',
    int limit = 24,
    int offset = 0,
  }) async {
    try {
      final res = await supabase.rpc('get_campaign_products', params: {
        'p_campaign_id': campaignId,
        'p_seed': seed,
        'p_category_id': categoryId,
        'p_min_price': null,
        'p_max_price': null,
        'p_min_discount': minDiscount,
        'p_sort': sort,
        'p_limit': limit,
        'p_offset': offset,
      });
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Campaign products error: $e');
      return [];
    }
  }

  /// يحتسب المشاهدة مرة واحدة لكل عرض
  Future<void> trackView(String campaignId, String productId) async {
    final key = '$campaignId-$productId';
    if (_seen.contains(key)) return;
    _seen.add(key);

    try {
      await supabase.rpc('track_campaign_view', params: {
        'p_campaign_id': campaignId,
        'p_product_id': productId,
      });
    } catch (e) {
      debugPrint('Track view error: $e');
    }
  }

  /// يحتسب النقر
  Future<void> trackClick(String campaignId, String productId) async {
    try {
      await supabase.rpc('track_campaign_click', params: {
        'p_campaign_id': campaignId,
        'p_product_id': productId,
      });
    } catch (e) {
      debugPrint('Track click error: $e');
    }
  }
}
