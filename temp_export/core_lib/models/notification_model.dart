class NotificationModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String title;
  final String body;
  final String type; // 'like', 'comment', 'order', 'reply'
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId; // معرف الشيء المرتبط (مثل معرف الريل أو المراجعة)

  NotificationModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.relatedId,
  });

  // تحويل البيانات من Map (JSON) إلى Object
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      relatedId: map['relatedId'],
    );
  }

  // تحويل الـ Object إلى Map للحفظ
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'relatedId': relatedId,
    };
  }

  // تحديث حالة الإشعار (مثلاً عند قراءته)
  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      relatedId: relatedId,
    );
  }
}
