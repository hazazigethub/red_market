// panel/lib/features/payments/payments_api.dart
// طلب شحن الرصيد من الموقع (Next.js): ينشئ الدفعة وجلسة الدفع، ويعيد رابط صفحة الدفع المدمجة.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const String kPaymentsApiBase = String.fromEnvironment(
  'PAYMENTS_API',
  defaultValue: 'https://www.redmarket.pro',
);

/// يعيد (رابط صفحة الدفع، رسالة خطأ) — أحدهما فقط غير فارغ
Future<(String?, String?)> createWalletCharge(double amount) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return (null, 'يجب تسجيل الدخول أولاً');

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
      return (
        null,
        body['error']?.toString() ?? 'تعذّر إنشاء الدفع (${res.statusCode})',
      );
    }
    return (url, null);
  } catch (_) {
    return (null, 'تعذّر الاتصال بخادم الدفع');
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
