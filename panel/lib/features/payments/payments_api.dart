// panel/lib/features/payments/payments_api.dart
// طلب شحن الرصيد من الموقع (Next.js)، ثم الانتقال لصفحة MyFatoorah.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// عنوان الموقع الذي ينشئ جلسة الدفع
/// محلياً: http://localhost:3000 — عند النشر يُستبدل بنطاق الموقع
const String kPaymentsApiBase = 'http://localhost:3000';

/// يبدأ شحن الرصيد. يعيد رسالة خطأ، أو null إذا انتقل لصفحة الدفع.
Future<String?> startWalletCharge(double amount) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return 'يجب تسجيل الدخول أولاً';

  try {
    final res = await http.post(
      Uri.parse('$kPaymentsApiBase/api/payments/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({'amount': amount}),
    );

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}

    final url = body['payment_url']?.toString();
    if (res.statusCode != 200 || url == null || url.isEmpty) {
      return body['error']?.toString() ?? 'تعذّر إنشاء الدفع (${res.statusCode})';
    }

    // نفس التبويب — لتجنّب حظر النوافذ المنبثقة في المتصفح
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    return null;
  } catch (_) {
    return 'تعذّر الاتصال بخادم الدفع';
  }
}

/// يحوّل الأرقام العربية/الهندية والفاصلة العربية إلى رقم
double parseAmount(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var s = input.trim();
  for (var i = 0; i < arabic.length; i++) {
    s = s.replaceAll(arabic[i], '$i');
  }
  s = s.replaceAll('٫', '.').replaceAll(',', '.');
  return double.tryParse(s) ?? 0;
}
