class ReviewModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerProfileImage;
  final String merchantId;
  final String? reelId; // اختياري: لربط التقييم بفيديو معين
  final double rating; // عدد النجوم (مثلاً من 1 إلى 5)
  final String comment;
  final String? reply; // رد التاجر على المراجعة
  final DateTime createdAt;
  final DateTime? repliedAt;

  ReviewModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerProfileImage,
    required this.merchantId,
    this.reelId,
    required this.rating,
    required this.comment,
    this.reply,
    required this.createdAt,
    this.repliedAt,
  });

  // تحويل البيانات من Map (JSON) إلى Object
  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerProfileImage: map['customerProfileImage'] ?? '',
      merchantId: map['merchantId'] ?? '',
      reelId: map['reelId'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      reply: map['reply'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      repliedAt:
          map['repliedAt'] != null ? DateTime.parse(map['repliedAt']) : null,
    );
  }

  // تحويل الـ Object إلى Map للحفظ في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerProfileImage': customerProfileImage,
      'merchantId': merchantId,
      'reelId': reelId,
      'rating': rating,
      'comment': comment,
      'reply': reply,
      'createdAt': createdAt.toIso8601String(),
      'repliedAt': repliedAt?.toIso8601String(),
    };
  }

  // وظيفة هامة جداً للسماح للتاجر بإضافة رد على المراجعة لاحقاً
  ReviewModel copyWith({
    String? reply,
    DateTime? repliedAt,
  }) {
    return ReviewModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerProfileImage: customerProfileImage,
      merchantId: merchantId,
      reelId: reelId,
      rating: rating,
      comment: comment,
      reply: reply ?? this.reply,
      createdAt: createdAt,
      repliedAt: repliedAt ?? this.repliedAt,
    );
  }
}
