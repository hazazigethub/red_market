// lib/providers/payment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// Providers
// ============================================================

// Myratoorah Service Singleton
final myratoorahServiceProvider = Provider((ref) {
  return MyratoorahService(
    apiKey: 'SK_SAU_o0dX0F2pBUQ0BZhfA9dD0JZ5y3DOIvKJ4Khwfln0knYBy3I8dBcw2Pk5FqTB3vw6',
    merchantId: 'red_market',
  );
});

// Supabase Client
final supabaseProvider = Provider((ref) => Supabase.instance.client);

// ============================================================
// Payment Creation
// ============================================================

class CreatePaymentRequest {
  final String merchantId;
  final double amount;
  final PaymentType paymentType;
  final String? referenceId;
  final String? subscriptionId;
  final String? bookingId;
  final String? splashAdId;

  CreatePaymentRequest({
    required this.merchantId,
    required this.amount,
    required this.paymentType,
    this.referenceId,
    this.subscriptionId,
    this.bookingId,
    this.splashAdId,
  });
}

final createPaymentProvider = FutureProvider.family<Payment, CreatePaymentRequest>((ref, request) async {
  final supabase = ref.watch(supabaseProvider);
  
  final vat = request.amount * 0.15;
  final total = request.amount + vat;

  try {
    final response = await supabase.from('payments').insert({
      'merchant_id': request.merchantId,
      'amount': request.amount,
      'vat_amount': vat,
      'total_amount': total,
      'payment_type': request.paymentType.toString().split('.').last,
      'reference_id': request.referenceId,
      'subscription_id': request.subscriptionId,
      'booking_id': request.bookingId,
      'splash_ad_id': request.splashAdId,
      'status': 'pending',
    }).select().single();

    return Payment.fromJson(response);
  } catch (e) {
    throw Exception('فشل إنشاء الدفعة: $e');
  }
});

// ============================================================
// Payment Session
// ============================================================

class PaymentSessionRequest {
  final String paymentId;
  final String returnUrl;
  final String webhookUrl;

  PaymentSessionRequest({
    required this.paymentId,
    required this.returnUrl,
    required this.webhookUrl,
  });
}

final paymentSessionProvider = FutureProvider.family<PaymentSessionResponse?, PaymentSessionRequest>((ref, request) async {
  final myratoorah = ref.watch(myratoorahServiceProvider);
  final supabase = ref.watch(supabaseProvider);

  // احصل على بيانات الدفعة
  final paymentData = await supabase
    .from('payments')
    .select()
    .eq('id', request.paymentId)
    .single();

  final payment = Payment.fromJson(paymentData);

  // أنشئ جلسة دفع
  final session = await myratoorah.createPaymentSession(
    orderId: request.paymentId,
    amount: payment.totalAmount,
    merchantReference: request.paymentId,
    returnUrl: request.returnUrl,
    webhookUrl: request.webhookUrl,
    description: payment.paymentTypeText,
  );

  if (session != null) {
    // حدّث معرّف الجلسة في الـ Database
    await supabase.from('payments').update({
      'myratoorah_session_id': session.sessionId,
      'status': 'processing',
    }).eq('id', request.paymentId);
  }

  return session;
});

// ============================================================
// Payment Status
// ============================================================

final paymentStatusProvider = FutureProvider.family<PaymentStatusResponse?, String>((ref, paymentId) async {
  final myratoorah = ref.watch(myratoorahServiceProvider);
  final supabase = ref.watch(supabaseProvider);

  // احصل على معرّف Myratoorah من الـ Database
  final paymentData = await supabase
    .from('payments')
    .select('myratoorah_payment_id')
    .eq('id', paymentId)
    .maybeSingle();

  if (paymentData?['myratoorah_payment_id'] == null) {
    return null;
  }

  return await myratoorah.getPaymentStatus(paymentData['myratoorah_payment_id']);
});

// ============================================================
// User Payments History
// ============================================================

final userPaymentsProvider = FutureProvider.family<List<Payment>, String>((ref, merchantId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
    .from('payments')
    .select()
    .eq('merchant_id', merchantId)
    .order('created_at', ascending: false)
    .limit(50);

  return (response as List).map((p) => Payment.fromJson(p)).toList();
});

// ============================================================
// Invoices
// ============================================================

final invoicesProvider = FutureProvider.family<List<Invoice>, String>((ref, merchantId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
    .from('invoices')
    .select()
    .eq('merchant_id', merchantId)
    .order('created_at', ascending: false)
    .limit(50);

  return (response as List).map((i) => Invoice.fromJson(i)).toList();
});

final invoiceDetailProvider = FutureProvider.family<Invoice?, String>((ref, invoiceId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
    .from('invoices')
    .select()
    .eq('id', invoiceId)
    .maybeSingle();

  return response != null ? Invoice.fromJson(response) : null;
});

// ============================================================
// Create Invoice
// ============================================================

class CreateInvoiceRequest {
  final String merchantId;
  final String invoiceNumber;
  final double subtotal;
  final double vatPercent;
  final String invoiceType;
  final String? description;
  final DateTime? dueDate;

  CreateInvoiceRequest({
    required this.merchantId,
    required this.invoiceNumber,
    required this.subtotal,
    this.vatPercent = 15,
    required this.invoiceType,
    this.description,
    this.dueDate,
  });
}

final createInvoiceProvider = FutureProvider.family<Invoice, CreateInvoiceRequest>((ref, request) async {
  final supabase = ref.watch(supabaseProvider);

  final vat = request.subtotal * (request.vatPercent / 100);
  final total = request.subtotal + vat;

  try {
    final response = await supabase.from('invoices').insert({
      'merchant_id': request.merchantId,
      'invoice_number': request.invoiceNumber,
      'invoice_date': DateTime.now().toIso8601String(),
      'due_date': request.dueDate?.toIso8601String(),
      'subtotal': request.subtotal,
      'vat_percent': request.vatPercent,
      'vat_amount': vat,
      'total_amount': total,
      'invoice_type': request.invoiceType,
      'description': request.description,
      'status': 'draft',
    }).select().single();

    return Invoice.fromJson(response);
  } catch (e) {
    throw Exception('فشل إنشاء الفاتورة: $e');
  }
});

// ============================================================
// Wallet Balance
// ============================================================

final merchantWalletProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, merchantId) async {
  final supabase = ref.watch(supabaseProvider);

  final response = await supabase
    .from('merchant_wallets')
    .select()
    .eq('merchant_id', merchantId)
    .maybeSingle();

  return response;
});

// ============================================================
// Payment Statistics
// ============================================================

class PaymentStats {
  final double totalPaid;
  final double pendingAmount;
  final int successfulPayments;
  final int failedPayments;

  PaymentStats({
    required this.totalPaid,
    required this.pendingAmount,
    required this.successfulPayments,
    required this.failedPayments,
  });
}

final paymentStatsProvider = FutureProvider.family<PaymentStats?, String>((ref, merchantId) async {
  final supabase = ref.watch(supabaseProvider);

  try {
    // الدفوعات المكتملة
    final completedResponse = await supabase
      .from('payments')
      .select('total_amount')
      .eq('merchant_id', merchantId)
      .eq('status', 'completed');

    // الدفوعات المعلقة
    final pendingResponse = await supabase
      .from('payments')
      .select('total_amount')
      .eq('merchant_id', merchantId)
      .eq('status', 'pending');

    // عدد النجاحات والأخطاء
    final successCount = await supabase
      .from('payments')
      .select('id', const FetchOptions(count: CountOption.exact))
      .eq('merchant_id', merchantId)
      .eq('status', 'completed');

    final failCount = await supabase
      .from('payments')
      .select('id', const FetchOptions(count: CountOption.exact))
      .eq('merchant_id', merchantId)
      .eq('status', 'failed');

    final totalPaid = (completedResponse as List)
      .fold<double>(0, (sum, p) => sum + (p['total_amount'] as num).toDouble());

    final pending = (pendingResponse as List)
      .fold<double>(0, (sum, p) => sum + (p['total_amount'] as num).toDouble());

    return PaymentStats(
      totalPaid: totalPaid,
      pendingAmount: pending,
      successfulPayments: successCount.length,
      failedPayments: failCount.length,
    );
  } catch (e) {
    return null;
  }
});

// ============================================================
// Refund Request
// ============================================================

class RefundRequestData {
  final String paymentId;
  final double amount;
  final String? reason;
  final String? bankAccount;
  final String? bankIban;

  RefundRequestData({
    required this.paymentId,
    required this.amount,
    this.reason,
    this.bankAccount,
    this.bankIban,
  });
}

final requestRefundProvider = FutureProvider.family<RefundResponse?, RefundRequestData>((ref, data) async {
  final myratoorah = ref.watch(myratoorahServiceProvider);
  final supabase = ref.watch(supabaseProvider);

  // معالجة الاسترجاع
  final refund = await myratoorah.processRefund(
    paymentId: data.paymentId,
    amount: data.amount,
    reason: data.reason,
    bankAccount: data.bankAccount,
    bankIban: data.bankIban,
  );

  if (refund != null) {
    // سجّل طلب الاسترجاع
    await supabase.from('refund_requests').insert({
      'merchant_id': (await supabase
        .from('payments')
        .select('merchant_id')
        .eq('id', data.paymentId)
        .maybeSingle())?['merchant_id'],
      'amount': data.amount,
      'bank_name': 'Myratoorah Refund',
      'bank_account_owner': 'Merchant',
      'bank_iban': data.bankIban,
      'status': 'processing',
      'payment_id': data.paymentId,
      'myratoorah_refund_id': refund.refundId,
    });
  }

  return refund;
});
