import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/app_router.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'dart:async';

final notificationsObserverProvider =
    Provider((ref) => NotificationsObserver(ref));

class NotificationsObserver {
  final Ref ref;
  final _supabase = Supabase.instance.client;
  bool _isListening = false; // لمنع التكرار
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  NotificationsObserver(this.ref);

  void startListening() {
    if (_isListening) return; // إذا كان يعمل مسبقاً لا تفعل شيئاً

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isListening = true;

    _sub = _supabase
        .from('notifications_log')
        .stream(primaryKey: ['id'])
        // فلترة مباشرة من السوبابيس لجلب الإشعارات المرسلة فقط
        .eq('status', 'sent')
        .order('created_at', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final notification = data.first;

            // التحقق من الوقت (لضمان عدم ظهور إشعارات قديمة جداً عند تشغيل التطبيق)
            final createdAt =
                DateTime.tryParse(notification['created_at']?.toString() ?? '');
            if (createdAt == null) return;
            if (createdAt.isBefore(
                DateTime.now().subtract(const Duration(seconds: 30)))) return;

            final String targetType =
                notification['target_type']?.toString() ?? '';
            final String? targetId = notification['target_id']?.toString();
            final String? segment = notification['segment_filter']?.toString();

            bool shouldShow = false;

            // منطق الفلترة الذكي
            if (targetType == 'all') {
              shouldShow = true;
            } else if (targetType == 'specific' && targetId == userId) {
              shouldShow = true;
            } else if (targetType == 'segment' && segment != null) {
              // التطبيق للعملاء فقط: تُعرض إشعارات شريحة العملاء
              if (segment.contains('users')) {
                shouldShow = true;
              }
            }

            if (shouldShow) {
              _showTopNotification(notification);
            }
          }
        });
  }

  /// إيقاف الاستماع وتحرير الاشتراك (يُستدعى عند تسجيل الخروج)
  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _isListening = false;
  }

  void _showTopNotification(Map<String, dynamic> data) {
    late OverlaySupportEntry entry;

    entry = showSimpleNotification(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          entry.dismiss();

          ref.read(routerProvider).push(RoutePaths.notifications);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data['title'] ?? 'إشعار جديد',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14),
            ),
            Text(
              data['body'] ?? '',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      leading: const Icon(Icons.notifications_active, color: Colors.white),
      background: const Color(0xFFD32027),
      duration: const Duration(seconds: 5),
    );
  }
}
