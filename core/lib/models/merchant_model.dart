class MerchantModel {
  final String id;
  final String storeName;
  final String description;
  final String logoUrl;
  final String coverImageUrl;
  final String category;
  final String? address;
  final String? whatsapp;
  final String? instagram;
  final double averageRating;
  final int reviewsCount;
  final bool isVerified;
  final List<String> showcaseImages;
  // الحقول المطلوبة للإحداثيات والمسافة
  final double latitude;
  final double longitude;

  MerchantModel({
    required this.id,
    required this.storeName,
    required this.description,
    required this.logoUrl,
    required this.coverImageUrl,
    required this.category,
    this.address,
    this.whatsapp,
    this.instagram,
    this.averageRating = 0.0,
    this.reviewsCount = 0,
    this.isVerified = false,
    this.showcaseImages = const [],
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  // ✅ الإصلاح النهائي: تعريف fromJson ليتوافق مع استدعاءات صفحة المفضلة وHomeScreen
  factory MerchantModel.fromJson(Map<String, dynamic> json) =>
      MerchantModel.fromMap(json);

  // ✅ تحويل البيانات من Supabase/Map مع معالجة ذكية لأسماء الحقول
  factory MerchantModel.fromMap(Map<String, dynamic> map) {
    return MerchantModel(
      id: map['id']?.toString() ?? '',
      storeName: map['store_name'] ?? map['storeName'] ?? '',
      description: map['store_description'] ?? map['description'] ?? '',
      logoUrl: map['logo_url'] ?? map['logoUrl'] ?? '',
      coverImageUrl: map['cover_image_url'] ?? map['coverImageUrl'] ?? '',
      category: map['category'] ?? '',
      address: map['address'],
      whatsapp: map['whatsapp'],
      instagram: map['instagram'],
      averageRating:
          (map['average_rating'] ?? map['averageRating'] ?? 0.0).toDouble(),
      reviewsCount: map['reviews_count'] ?? map['reviewsCount'] ?? 0,
      isVerified: map['is_verified'] ?? map['isVerified'] ?? false,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      showcaseImages: map['showcase_images'] != null
          ? List<String>.from(map['showcase_images'])
          : [],
    );
  }

  // ✅ تحويل الموديل لـ Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_name': storeName,
      'description': description,
      'logo_url': logoUrl,
      'cover_image_url': coverImageUrl,
      'category': category,
      'address': address,
      'whatsapp': whatsapp,
      'instagram': instagram,
      'average_rating': averageRating,
      'reviews_count': reviewsCount,
      'is_verified': isVerified,
      'latitude': latitude,
      'showcase_images': showcaseImages,
      'longitude': longitude,
    };
  }

  // ✅ تحديث: تم إضافة showcaseImages داخل الـ return لضمان عدم ضياع الصور
  MerchantModel copyWith({
    String? id,
    String? storeName,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
    String? category,
    String? address,
    String? whatsapp,
    String? instagram,
    double? averageRating,
    int? reviewsCount,
    bool? isVerified,
    double? latitude,
    double? longitude,
    List<String>? showcaseImages,
  }) {
    return MerchantModel(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      category: category ?? this.category,
      address: address ?? this.address,
      whatsapp: whatsapp ?? this.whatsapp,
      instagram: instagram ?? this.instagram,
      averageRating: averageRating ?? this.averageRating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isVerified: isVerified ?? this.isVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      showcaseImages: showcaseImages ?? this.showcaseImages, // ✅ تم الإصلاح هنا
    );
  }
}
