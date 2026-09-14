import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// معالج الرسائل في الخلفية — يجب أن يكون دالة عليا
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 إشعار في الخلفية: ${message.messageId}');
}

/// خدمة الإشعارات المنبثقة
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channelId = 'red_market_channel';
  static const _channelName = 'إشعارات رد ماركت';

  final _messaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _local;

  bool _initialized = false;

  /// تهيئة الخدمة — تُستدعى مرة واحدة عند الإقلاع
  Future<void> init(FlutterLocalNotificationsPlugin localPlugin) async {
    if (_initialized) return;
    _local = localPlugin;

    try {
      // قناة أندرويد — لازمة لظهور الإشعار على شاشة القفل
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'إشعارات العروض والمتاجر',
        importance: Importance.high,
      );

      await _local
          ?.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // طلب الإذن
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('🔔 إذن الإشعارات: ${settings.authorizationStatus}');

      // رسالة والتطبيق مفتوح
      FirebaseMessaging.onMessage.listen(_showLocal);

      // تحديث الرمز عند تغيّره
      _messaging.onTokenRefresh.listen(saveToken);

      _initialized = true;
    } catch (e) {
      debugPrint('Push init error: $e');
    }
  }

  /// يجلب الرمز ويحفظه — يُستدعى بعد تسجيل الدخول
  Future<void> registerDevice() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await saveToken(token);
    } catch (e) {
      debugPrint('Get token error: $e');
    }
  }

  /// يحفظ رمز الجهاز في قاعدة البيانات
  Future<void> saveToken(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      String platform = 'unknown';
      if (defaultTargetPlatform == TargetPlatform.android) {
        platform = 'android';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
      }

      await supabase.from('device_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('✅ رمز الجهاز محفوظ');
    } catch (e) {
      debugPrint('Save token error: $e');
    }
  }

  /// يوقف الرمز عند الخروج
  Future<void> unregisterDevice() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('device_tokens')
          .update({'is_active': false}).eq('token', token);
    } catch (e) {
      debugPrint('Unregister error: $e');
    }
  }

  /// يعرض الإشعار محلياً حين يكون التطبيق مفتوحاً
  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || _local == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _local!.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }
}
