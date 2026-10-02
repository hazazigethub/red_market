class ReelModel {
  final String id;
  final String merchantId;
  final String merchantName;
  final String merchantProfileImage;
  final String videoUrl;
  final String? title;
  final String? description;
  final String thumbnailUrl;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final String? productId; // ✅ مضاف

  ReelModel({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.merchantProfileImage,
    required this.videoUrl,
    this.title,
    this.description,
    required this.thumbnailUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.productId, // ✅ مضاف
  });

  factory ReelModel.fromMap(Map<String, dynamic> map) {
    return ReelModel(
      id: map['id']?.toString() ?? '',
      merchantId: map['merchant_id']?.toString() ?? '',
      merchantName: map['merchant_name'] ?? 'تاجر غير معروف',
      merchantProfileImage: map['merchant_profile_image'] ?? '',
      videoUrl: map['video_url'] ?? '',
      title: map['title'],
      description: map['description'],
      thumbnailUrl: map['thumbnail_url'] ?? '',
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (map['comments_count'] as num?)?.toInt() ?? 0,
      isLikedByMe: map['is_liked_by_me'] ?? false,
      productId: map['product_id']?.toString(), // ✅ مضاف
    );
  }

  ReelModel copyWith({
    String? title,
    String? description,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
    String? videoUrl,
    String? thumbnailUrl,
    String? productId, // ✅ مضاف
  }) {
    return ReelModel(
      id: id,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantProfileImage: merchantProfileImage,
      videoUrl: videoUrl ?? this.videoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      productId: productId ?? this.productId, // ✅ مضاف
    );
  }
}
