// lib/models/payment_models.dart
import 'package:intl/intl.dart';

// ============================================================
// نموذج الدفع (Payment)
// ============================================================

class Payment {
  final String id;
  final String merchantId;
  
  // المبلغ
  final double amount;
  final String currency;
  final double vatAmount;
  final double totalAmount;
  
  // نوع الدفع
  final PaymentType paymentType;
  
  // المرجع
  final String? referenceId;
  final String? subscriptionId;
  final String? bookingId;
  final String? splashAdId;
  
  // حالة الدفع
  final PaymentStatus status;
  
  // بيانات Myratoorah
  final String? myratoorah_payment_id;
  final String? myratoorah_session_id;
  final String? myratoorah_order_id;
  final PaymentMethod? paymentMethod;
  
  // الأخطاء
  final String? failureReason;
  
  // المواعيد
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  
  Payment({
    required this.id,
    required this.merchantId,
    required this.amount,
    this.currency = 'SAR',
    this.vatAmount = 0,
    required this.totalAmount,
    required this.paymentType,
    this.referenceId,
    this.subscriptionId,
    this.bookingId,
    this.splashAdId,
    required this.status,
    this.myratoorah_payment_id,
    this.myratoorah_session_id,
    this.myratoorah_order_id,
    this.paymentMethod,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? '',
      merchantId: json['merchant_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'SAR',
      vatAmount: (json['vat_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.toString().split('.').last == json['payment_type'],
        orElse: () => PaymentType.subscription,
      ),
      referenceId: json['reference_id'],
      subscriptionId: json['subscription_id'],
      bookingId: json['booking_id'],
      splashAdId: json['splash_ad_id'],
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      myratoorah_payment_id: json['myratoorah_payment_id'],
      myratoorah_session_id: json['myratoorah_session_id'],
      myratoorah_order_id: json['myratoorah_order_id'],
      paymentMethod: json['payment_method'] != null 
        ? PaymentMethod.values.firstWhere(
            (e) => e.toString().split('.').last == json['payment_method'],
            orElse: () => PaymentMethod.card,
          )
        : null,
      failureReason: json['failure_reason'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant_id': merchantId,
    'amount': amount,
    'currency': currency,
    'vat_amount': vatAmount,
    'total_amount': totalAmount,
    'payment_type': paymentType.toString().split('.').last,
    'reference_id': referenceId,
    'subscription_id': subscriptionId,
    'booking_id': bookingId,
    'splash_ad_id': splashAdId,
    'status': status.toString().split('.').last,
    'myratoorah_payment_id': myratoorah_payment_id,
    'myratoorah_session_id': myratoorah_session_id,
    'myratoorah_order_id': myratoorah_order_id,
    'payment_method': paymentMethod?.toString().split('.').last,
    'failure_reason': failureReason,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  String get statusText => _statusText[status] ?? '';
  String get paymentTypeText => _paymentTypeText[paymentType] ?? '';
  String get formattedAmount => '${amount.toStringAsFixed(2)} $currency';
  String get formattedTotal => '${totalAmount.toStringAsFixed(2)} $currency';
  String get createdAtFormatted => DateFormat('dd/MM/yyyy HH:mm', 'ar').format(createdAt);
}

---

// ============================================================
// نموذج الفاتورة (Invoice)
// ============================================================

class Invoice {
  final String id;
  final String merchantId;
  
  // بيانات الفاتورة
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  
  // النوع
  final InvoiceType invoiceType;
  
  // المبلغ
  final double subtotal;
  final double vatPercent;
  final double vatAmount;
  final double totalAmount;
  
  // الحالة
  final InvoiceStatus status;
  
  // المرجع
  final String? paymentId;
  final String? subscriptionId;
  final String? bookingId;
  
  // التفاصيل
  final String? description;
  final String? notes;
  final String paymentTerms;
  
  // المواعيد
  final DateTime createdAt;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final DateTime updatedAt;

  Invoice({
    required this.id,
    required this.merchantId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    required this.invoiceType,
    required this.subtotal,
    this.vatPercent = 15,
    required this.vatAmount,
    required this.totalAmount,
    required this.status,
    this.paymentId,
    this.subscriptionId,
    this.bookingId,
    this.description,
    this.notes,
    this.paymentTerms = 'Net 30',
    required this.createdAt,
    this.issuedAt,
    this.paidAt,
    required this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      merchantId: json['merchant_id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      invoiceDate: DateTime.parse(json['invoice_date'] ?? DateTime.now().toIso8601String()),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      invoiceType: InvoiceType.values.firstWhere(
        (e) => e.toString().split('.').last == json['invoice_type'],
        orElse: () => InvoiceType.subscription,
      ),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      vatPercent: (json['vat_percent'] ?? 15).toDouble(),
      vatAmount: (json['vat_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      paymentId: json['payment_id'],
      subscriptionId: json['subscription_id'],
      bookingId: json['booking_id'],
      description: json['description'],
      notes: json['notes'],
      paymentTerms: json['payment_terms'] ?? 'Net 30',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at']) : null,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant_id': merchantId,
    'invoice_number': invoiceNumber,
    'invoice_date': invoiceDate.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'invoice_type': invoiceType.toString().split('.').last,
    'subtotal': subtotal,
    'vat_percent': vatPercent,
    'vat_amount': vatAmount,
    'total_amount': totalAmount,
    'status': status.toString().split('.').last,
    'payment_id': paymentId,
    'subscription_id': subscriptionId,
    'booking_id': bookingId,
    'description': description,
    'notes': notes,
    'payment_terms': paymentTerms,
    'created_at': createdAt.toIso8601String(),
    'issued_at': issuedAt?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  String get statusText => _invoiceStatusText[status] ?? '';
  String get invoiceTypeText => _invoiceTypeText[invoiceType] ?? '';
  String get formattedTotal => '${totalAmount.toStringAsFixed(2)} ر.س';
  String get formattedInvoiceDate => DateFormat('dd/MM/yyyy', 'ar').format(invoiceDate);
}

---

// ============================================================
// Enums
// ============================================================

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

enum PaymentType {
  subscription,
  banner_booking,
  splash_ad,
}

enum PaymentMethod {
  card,
  wallet,
  bank_transfer,
}

enum InvoiceStatus {
  draft,
  issued,
  paid,
  partially_paid,
  overdue,
  cancelled,
}

enum InvoiceType {
  subscription,
  banner,
  splash_ad,
  custom,
}

---

// ============================================================
// خريطة النصوص (Text Maps)
// ============================================================

const Map<PaymentStatus, String> _statusText = {
  PaymentStatus.pending: 'قيد الانتظار',
  PaymentStatus.processing: 'جاري المعالجة',
  PaymentStatus.completed: 'مكتمل',
  PaymentStatus.failed: 'فشل',
  PaymentStatus.cancelled: 'ملغى',
};

const Map<PaymentType, String> _paymentTypeText = {
  PaymentType.subscription: 'اشتراك',
  PaymentType.banner_booking: 'حجز بنر',
  PaymentType.splash_ad: 'إعلان الشاشة الرئيسية',
};

const Map<InvoiceStatus, String> _invoiceStatusText = {
  InvoiceStatus.draft: 'مسودة',
  InvoiceStatus.issued: 'مُصدرة',
  InvoiceStatus.paid: 'مدفوعة',
  InvoiceStatus.partially_paid: 'مدفوعة جزئياً',
  InvoiceStatus.overdue: 'متأخرة',
  InvoiceStatus.cancelled: 'ملغاة',
};

const Map<InvoiceType, String> _invoiceTypeText = {
  InvoiceType.subscription: 'فاتورة اشتراك',
  InvoiceType.banner: 'فاتورة بنر',
  InvoiceType.splash_ad: 'فاتورة إعلان',
  InvoiceType.custom: 'فاتورة مخصصة',
};
