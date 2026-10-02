import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تتبّع ظهور البنرات ونقراتها
class BannerTracking {
  BannerTracking._();

  /// يمنع تكرار احتساب البنر نفسه في الجلسة
  static final Set<String> _seen = <String>{};

  /// يُحتسب الظهور مرة واحدة لكل بنر
  static Future<void> impression(String? bookingId) async {
    if (bookingId == null || bookingId.isEmpty) return;
    if (_seen.contains(bookingId)) return;
    _seen.add(bookingId);

    try {
      await Supabase.instance.client.rpc(
        'track_banner_impression',
        params: {'p_booking_id': bookingId},
      );
    } catch (e) {
      debugPrint('Impression error: $e');
    }
  }

  /// يُحتسب النقر في كل ضغطة
  static Future<void> click(String? bookingId) async {
    if (bookingId == null || bookingId.isEmpty) return;

    try {
      await Supabase.instance.client.rpc(
        'track_banner_click',
        params: {'p_booking_id': bookingId},
      );
    } catch (e) {
      debugPrint('Click error: $e');
    }
  }
}
