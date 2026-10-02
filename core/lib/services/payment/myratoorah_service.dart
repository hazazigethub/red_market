// lib/services/payment/myratoorah_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class MyratoorahService {
  static const String _baseUrl = 'https://api.myratoorah.com/v3';
  
  final String apiKey;
  final String merchantId;
  
  MyratoorahService({
    required this.apiKey,
    this.merchantId = 'red_market',
  });

  // ============================================================
  // Headers
  // ============================================================
  
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ============================================================
  // 1️⃣ إنشاء جلسة دفع (Payment Session)
  // ============================================================
  
  Future<PaymentSessionResponse?> createPaymentSession({
    required String orderId,
    required double amount,
    required String merchantReference,
    required String returnUrl,
    required String webhookUrl,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = {
        'amount': amount,
        'currency': 'SAR',
        'order_reference': merchantReference,
        'customer': {
          'name': 'Red Market Merchant',
          'email': 'redmarket.sa@outlook.com',
          'mobile': '+966559216860',
        },
        'order': {
          'description': description ?? 'Red Market Payment',
          'items': [
            {
              'name': description ?? 'Service Fee',
              'quantity': 1,
              'price': amount,
            }
          ],
        },
        'redirect_urls': {
          'success': '$returnUrl?status=success',
          'failure': '$returnUrl?status=failure',
        },
        'webhook': {
          'url': webhookUrl,
          'events': [
            'payment.completed',
            'payment.failed',
            'payment.cancelled',
          ],
        },
        'metadata': metadata ?? {},
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/payments/session'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return PaymentSessionResponse.fromJson(data);
      } else {
        debugPrint('❌ خطأ إنشاء الجلسة: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ استثناء إنشاء الجلسة: $e');
      return null;
    }
  }

  // ============================================================
  // 2️⃣ الحصول على حالة الدفع (Get Payment Status)
  // ============================================================
  
  Future<PaymentStatusResponse?> getPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payments/$paymentId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PaymentStatusResponse.fromJson(data);
      } else {
        debugPrint('❌ خطأ الحصول على الحالة: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ استثناء الحصول على الحالة: $e');
      return null;
    }
  }

  // ============================================================
  // 3️⃣ إنشاء فاتورة (Create Invoice)
  // ============================================================
  
  Future<InvoiceResponse?> createInvoice({
    required String invoiceNumber,
    required double amount,
    required String description,
    String? customerId,
    String? email,
    String? phone,
    List<InvoiceItem>? items,
    DateTime? dueDate,
  }) async {
    try {
      final body = {
        'invoice_number': invoiceNumber,
        'amount': amount,
        'currency': 'SAR',
        'description': description,
        'customer': {
          'id': customerId,
          'email': email ?? 'redmarket.sa@outlook.com',
          'mobile': phone ?? '+966559216860',
        },
        'items': items?.map((i) => i.toJson()).toList() ?? [],
        'due_date': dueDate?.toIso8601String(),
        'vat_percent': 15,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/invoices'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return InvoiceResponse.fromJson(data);
      } else {
        debugPrint('❌ خطأ إنشاء الفاتورة: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ استثناء إنشاء الفاتورة: $e');
      return null;
    }
  }

  // ============================================================
  // 4️⃣ معالجة استرجاع المال (Refund)
  // ============================================================
  
  Future<RefundResponse?> processRefund({
    required String paymentId,
    required double amount,
    String? reason,
    String? bankAccount,
    String? bankIban,
  }) async {
    try {
      final body = {
        'payment_id': paymentId,
        'amount': amount,
        'currency': 'SAR',
        'reason': reason ?? 'Customer Request',
        'bank_details': bankAccount != null ? {
          'account_owner': 'Merchant Account',
          'iban': bankIban,
          'bank_name': 'Not Specified',
        } : null,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/refunds'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return RefundResponse.fromJson(data);
      } else {
        debugPrint('❌ خطأ معالجة الاسترجاع: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ استثناء معالجة الاسترجاع: $e');
      return null;
    }
  }

  // ============================================================
  // 5️⃣ الحصول على قائمة الدفوعات (Get Payments List)
  // ============================================================
  
  Future<List<PaymentStatusResponse>?> getPaymentsList({
    int page = 1,
    int limit = 50,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
      };

      final uri = Uri.parse('$_baseUrl/payments').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> payments = data['data'] ?? [];
        return payments
          .map((p) => PaymentStatusResponse.fromJson(p))
          .toList();
      } else {
        debugPrint('❌ خطأ جلب القائمة: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ استثناء جلب القائمة: $e');
      return null;
    }
  }

  // ============================================================
  // 6️⃣ التحقق من webhook
  // ============================================================
  
  bool verifyWebhookSignature(
    String payload,
    String signature,
    String secret,
  ) {
    // التحقق من توقيع Webhook
    // الصيغة: HMAC-SHA256(payload, secret)
    return true; // تحتاج لتطبيق HMAC verification
  }
}



// ============================================================
// Response Models
// ============================================================

class PaymentSessionResponse {
  final String sessionId;
  final String paymentUrl;
  final double amount;
  final String status;
  final DateTime createdAt;

  PaymentSessionResponse({
    required this.sessionId,
    required this.paymentUrl,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory PaymentSessionResponse.fromJson(Map<String, dynamic> json) {
    return PaymentSessionResponse(
      sessionId: json['session_id'] ?? json['id'] ?? '',
      paymentUrl: json['payment_url'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}



class PaymentStatusResponse {
  final String paymentId;
  final String status; // success | failed | pending | cancelled
  final double amount;
  final String currency;
  final String? orderReference;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  PaymentStatusResponse({
    required this.paymentId,
    required this.status,
    required this.amount,
    required this.currency,
    this.orderReference,
    this.paymentMethod,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      paymentId: json['id'] ?? json['payment_id'] ?? '',
      status: json['status'] ?? 'pending',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'SAR',
      orderReference: json['order_reference'],
      paymentMethod: json['payment_method'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null 
        ? DateTime.parse(json['completed_at']) 
        : null,
      metadata: json['metadata'],
    );
  }
}



class InvoiceResponse {
  final String invoiceId;
  final String invoiceNumber;
  final double amount;
  final String status;
  final String? paymentLink;
  final DateTime createdAt;

  InvoiceResponse({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
    required this.status,
    this.paymentLink,
    required this.createdAt,
  });

  factory InvoiceResponse.fromJson(Map<String, dynamic> json) {
    return InvoiceResponse(
      invoiceId: json['id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      paymentLink: json['payment_link'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}



class RefundResponse {
  final String refundId;
  final String paymentId;
  final double amount;
  final String status;
  final DateTime createdAt;

  RefundResponse({
    required this.refundId,
    required this.paymentId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory RefundResponse.fromJson(Map<String, dynamic> json) {
    return RefundResponse(
      refundId: json['id'] ?? '',
      paymentId: json['payment_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}



class InvoiceItem {
  final String name;
  final int quantity;
  final double price;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'price': price,
  };
}
