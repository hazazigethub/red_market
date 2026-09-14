class UserModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String profileImageUrl;
  final String? location;
  final String userType; // 'customer' أو 'merchant'
  final String role; // ✅ الصفة الجديدة: 'user' أو 'super_admin' أو 'sub_admin'
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.profileImageUrl,
    this.location,
    required this.userType,
    required this.role, // ✅ مضافة هنا
    required this.createdAt,
  });

  // 1. تحويل البيانات من Map إلى Object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phone'] ?? '', // ملاحظة: تأكد أنها 'phone' كما في SQL
      profileImageUrl: map['profile_image_url'] ?? '',
      location: map['location'],
      userType: map['user_type'] ?? 'customer',
      role: map['role'] ?? 'user', // ✅ قراءة الرتبة من قاعدة البيانات
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  // 2. تحويل الـ Object إلى Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phoneNumber,
      'profile_image_url': profileImageUrl,
      'location': location,
      'user_type': userType,
      'role': role, // ✅ إرسال الرتبة للسيرفر
      'created_at': createdAt.toIso8601String(),
    };
  }

  // 3. وظيفة لتحديث قيم معينة
  UserModel copyWith({
    String? name,
    String? profileImageUrl,
    String? location,
    String? phoneNumber,
    String? role, // ✅ إمكانية تحديث الرتبة
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      location: location ?? this.location,
      userType: userType,
      role: role ?? this.role, // ✅ تحديث الرتبة
      createdAt: createdAt,
    );
  }
}
