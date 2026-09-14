// lib/core/models/product_model.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductModel {
  final String id;
  final String merchantId;
  final String? storeName;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final bool isOffer;
  final int? likesCount;
  final List<String> imagesUrl;
  final String category;
  final String? categoryName;
  final String? storeCategory;
  final String? region;
  final int stock;
  final bool isAvailable;
  final DateTime createdAt;
  final String? productUrl;
  final bool isFlashSale;
  final DateTime? flashSaleExpiry;

  ProductModel({
    required this.id,
    required this.merchantId,
    this.storeName,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    this.isOffer = false,
    this.likesCount,
    required this.imagesUrl,
    required this.category,
    this.categoryName,
    this.storeCategory,
    this.region,
    this.stock = 0,
    this.isAvailable = true,
    required this.createdAt,
    this.productUrl,
    this.isFlashSale = false,
    this.flashSaleExpiry,
  });

  bool get isFlashSaleActive {
    if (!isFlashSale || flashSaleExpiry == null) return false;
    return flashSaleExpiry!.isAfter(DateTime.now());
  }

  Duration get remainingTime {
    if (flashSaleExpiry == null) return Duration.zero;
    return flashSaleExpiry!.difference(DateTime.now());
  }

  String? get imageUrl {
    if (imagesUrl.isEmpty) return null;
    final url = imagesUrl.first;
    if (url.startsWith('http')) return url;
    return Supabase.instance.client.storage
        .from('products-images')
        .getPublicUrl(url.trim());
  }

  String? get discountPercentage {
    if (oldPrice == null || oldPrice! <= price) return null;
    final discount = ((oldPrice! - price) / oldPrice!) * 100;
    return "${discount.round()}%";
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedImages = [];

    if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      parsedImages.add(json['image_url'].toString());
    }

    if (json['images_url'] != null && json['images_url'] is List) {
      parsedImages.addAll(List<String>.from(json['images_url']));
    }

    parsedImages = parsedImages.where((img) => img.isNotEmpty).toList();

    // ✅ استخراج اسم القسم من العلاقة
    String? categoryName;
    if (json['product_categories'] != null &&
        json['product_categories'] is Map) {
      categoryName = json['product_categories']['name']?.toString();
    }

    return ProductModel(
      id: json['id']?.toString() ?? '',
      merchantId: json['merchant_id']?.toString() ?? '',
      storeName: json['store_name']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      isOffer: (json['is_offer'] as bool?) ?? false,
      likesCount: json['likes_count'] as int?,
      imagesUrl: parsedImages,
      category: json['category']?.toString() ?? '',
      categoryName: categoryName,
      storeCategory: json['store_category']?.toString(),
      region: json['region'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      isAvailable: (json['is_available'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      productUrl: json['product_url']?.toString(),
      isFlashSale: (json['is_flash_sale'] as bool?) ?? false,
      flashSaleExpiry: json['flash_sale_expiry'] != null
          ? DateTime.parse(json['flash_sale_expiry'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'store_name': storeName,
      'name': name,
      'description': description,
      'price': price,
      'old_price': oldPrice,
      'is_offer': isOffer,
      'likes_count': likesCount,
      'images_url': imagesUrl,
      'category': category,
      'region': region,
      'stock': stock,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'product_url': productUrl,
      'is_flash_sale': isFlashSale,
      'flash_sale_expiry': flashSaleExpiry?.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? merchantId,
    String? storeName,
    String? name,
    String? description,
    double? price,
    double? oldPrice,
    bool? isOffer,
    int? likesCount,
    List<String>? imagesUrl,
    String? category,
    String? categoryName,
    String? storeCategory,
    String? region,
    int? stock,
    bool? isAvailable,
    DateTime? createdAt,
    String? productUrl,
    bool? isFlashSale,
    DateTime? flashSaleExpiry,
  }) {
    return ProductModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      storeName: storeName ?? this.storeName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      isOffer: isOffer ?? this.isOffer,
      likesCount: likesCount ?? this.likesCount,
      imagesUrl: imagesUrl ?? this.imagesUrl,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      storeCategory: storeCategory ?? this.storeCategory,
      region: region ?? this.region,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      productUrl: productUrl ?? this.productUrl,
      isFlashSale: isFlashSale ?? this.isFlashSale,
      flashSaleExpiry: flashSaleExpiry ?? this.flashSaleExpiry,
    );
  }
}
