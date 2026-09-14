// lib/features/merchant/dashboard/presentation/pages/reviews_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class ReviewData {
  final String id;
  final String customerId;

  // ✅ مفاتيح مهمة للتحديث (بدون الاعتماد على id)
  final String orderId;
  final String? productId;

  final String title; // product_name أو "تقييم المتجر"
  final String comment; // اختياري
  final double rating;
  final DateTime createdAt;
  final String? merchantReply;

  ReviewData({
    required this.id,
    required this.customerId,
    required this.orderId,
    this.productId,
    required this.title,
    required this.comment,
    required this.rating,
    required this.createdAt,
    this.merchantReply,
  });

  factory ReviewData.fromProduct(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString().trim();
    final orderId = (map['order_id'] ?? '').toString();
    final productId = (map['product_id'] ?? '').toString();
    final customerId = (map['customer_id'] ?? '').toString();

    // ✅ ID احتياطي منطقي (بدون \_)
    final fallbackId = "${orderId}_${productId}_$customerId";

    return ReviewData(
      id: id.isNotEmpty ? id : fallbackId,
      customerId: customerId,
      orderId: orderId,
      productId: productId,
      title: (map['product_name'] ?? 'عرض').toString(),
      comment: (map['comment'] ?? '').toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      merchantReply: map['merchant_reply']?.toString(),
    );
  }

  factory ReviewData.fromStore(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString().trim();
    final orderId = (map['order_id'] ?? '').toString();
    final customerId = (map['customer_id'] ?? '').toString();

    final fallbackId = "${orderId}_$customerId";

    return ReviewData(
      id: id.isNotEmpty ? id : fallbackId,
      customerId: customerId,
      orderId: orderId,
      productId: null,
      title: "تقييم المتجر",
      comment:
          (map['comment'] ?? '').toString(), // غالبًا فاضي في store_reviews
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      merchantReply: map['merchant_reply']?.toString(),
    );
  }
}

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final supabase = Supabase.instance.client;

  int _tab = 0; // 0 products, 1 store

  // ✅ إرسال الرد (نفس الجدول حسب التبويب) بدون الاعتماد على id
  Future<void> _submitReply({
    required ReviewData review,
    required String replyText,
    required bool isProduct,
  }) async {
    final merchantId = supabase.auth.currentUser?.id;
    if (merchantId == null) return;

    try {
      final table = isProduct ? 'product_reviews' : 'store_reviews';

      final q = supabase.from(table).update({'merchant_reply': replyText}).eq(
        'merchant_id',
        merchantId,
      );

      if (isProduct) {
        // ✅ product_reviews مفتاحه المركّب
        await q
            .eq('order_id', review.orderId)
            .eq('product_id', review.productId ?? '')
            .eq('customer_id', review.customerId);
      } else {
        // ✅ store_reviews مفتاحه المركّب
        await q
            .eq('order_id', review.orderId)
            .eq('customer_id', review.customerId);
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // ✅ إغلاق نافذة الرد
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم اعتماد ردك بنجاح ✅",
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("حدث خطأ: $e", style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _fmtDate(DateTime dt) => DateFormat('yyyy/MM/dd').format(dt);

  int _starsInt(double r) {
    final v = r.round();
    if (v < 0) return 0;
    if (v > 5) return 5;
    return v;
  }

  Widget _stars(double rating) {
    final s = _starsInt(rating);
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          Icons.star_rounded,
          color: i < s ? Colors.orange : Colors.grey.shade300,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(List<ReviewData> reviews, bool isDark) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    final total = reviews.length.toDouble();
    final excellent = reviews.where((r) => r.rating >= 4.5).length;
    final good = reviews.where((r) => r.rating >= 3.5 && r.rating < 4.5).length;
    final average =
        reviews.where((r) => r.rating >= 2.5 && r.rating < 3.5).length;
    final weak = reviews.where((r) => r.rating < 2.5).length;

    Widget indicator(String label, Color color, int count) {
      final pct = total == 0 ? 0 : ((count / total) * 100).toInt();
      return Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "$pct%",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
        ],
        border:
            isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ملخص التقييمات",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              indicator("ممتاز", Colors.green, excellent),
              indicator("جيد", Colors.blue, good),
              indicator("متوسط", Colors.orange, average),
              indicator("ضعيف", Colors.red, weak),
            ],
          ),
          const SizedBox(height: 25),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (excellent > 0)
                    Expanded(
                        flex: excellent, child: Container(color: Colors.green)),
                  if (good > 0)
                    Expanded(flex: good, child: Container(color: Colors.blue)),
                  if (average > 0)
                    Expanded(
                        flex: average, child: Container(color: Colors.orange)),
                  if (weak > 0)
                    Expanded(flex: weak, child: Container(color: Colors.red)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(ReviewData review, bool isDark, bool isProduct) {
    final formattedDate = _fmtDate(review.createdAt);
    final hasComment = review.comment.trim().isNotEmpty;
    final hasReply =
        review.merchantReply != null && review.merchantReply!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  review.title.isNotEmpty ? review.title[0] : "★",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    _stars(review.rating),
                  ],
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // تعليق (اختياري)
          if (hasComment)
            Text(
              review.comment,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Cairo',
              ),
            )
          else
            Text(
              "بدون تعليق",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),

          if (hasReply)
            Container(
              margin: const EdgeInsets.only(top: 15),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: Color(0xFF4CAF50)),
                      SizedBox(width: 5),
                      Text(
                        "ردك:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    review.merchantReply!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 15),

          // ✅ زر الرد يظهر فقط إذا:
          // 1) فيه تعليق (مو فاضي)
          // 2) ما فيه رد سابق
          if (hasComment && !hasReply)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    _showReplyBottomSheet(review, isDark, isProduct),
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: const Text(
                  "رد على التقييم",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showReplyBottomSheet(ReviewData review, bool isDark, bool isProduct) {
    // ✅ حماية: إذا بدون تعليق لا نفتح الرد
    if (review.comment.trim().isEmpty) return;

    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 15,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "الرد على التقييم",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                review.title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: replyController,
                autofocus: true,
                maxLines: 4,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontFamily: 'Cairo',
                ),
                decoration: InputDecoration(
                  hintText: "اكتب ردك هنا...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final text = replyController.text.trim();
                    if (text.isEmpty) return;

                    _submitReply(
                      review: review,
                      replyText: text,
                      isProduct: isProduct,
                    );
                  },
                  child: const Text(
                    "إرسال الرد",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final merchantId = supabase.auth.currentUser?.id;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: isDark ? Colors.white : Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "تقييمات العملاء",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: merchantId == null
            ? const Center(
                child: Text("سجل دخول أولاً",
                    style: TextStyle(fontFamily: 'Cairo')),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _tabBtn(
                            title: "تقييمات العروض",
                            active: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _tabBtn(
                            title: "تقييمات المتجر",
                            active: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _tab == 0
                        ? _productsStream(merchantId, isDark)
                        : _storeStream(merchantId, isDark),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tabBtn({
    required String title,
    required bool active,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const primary = Color(0xFF4CAF50);
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? primary.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color:
                  active ? primary : (isDark ? Colors.white : Colors.black87),
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _productsStream(String merchantId, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('product_reviews')
          // ✅ primaryKey مركّب (بدل id)
          .stream(primaryKey: ['order_id', 'product_id', 'customer_id'])
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "خطأ في جلب تقييمات العروض:\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_outline_rounded,
                    size: 80, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 15),
                const Text("لا توجد تقييمات عروض حتى الآن",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ],
            ),
          );
        }

        final reviews =
            snapshot.data!.map((e) => ReviewData.fromProduct(e)).toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnalyticsCard(reviews, isDark),
              const SizedBox(height: 24),
              Text("أحدث المراجعات (${reviews.length})",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : Colors.black87,
                  )),
              const SizedBox(height: 12),
              ...reviews.map((r) => _buildReviewItem(r, isDark, true)),
            ],
          ),
        );
      },
    );
  }

  Widget _storeStream(String merchantId, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('store_reviews')
          // ✅ primaryKey مركّب (بدل id)
          .stream(primaryKey: ['order_id', 'customer_id'])
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "خطأ في جلب تقييمات المتجر:\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined,
                    size: 80, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 15),
                const Text("لا توجد تقييمات متجر حتى الآن",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ],
            ),
          );
        }

        final reviews =
            snapshot.data!.map((e) => ReviewData.fromStore(e)).toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnalyticsCard(reviews, isDark),
              const SizedBox(height: 24),
              Text("أحدث التقييمات (${reviews.length})",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : Colors.black87,
                  )),
              const SizedBox(height: 12),
              ...reviews.map((r) => _buildReviewItem(r, isDark, false)),
            ],
          ),
        );
      },
    );
  }
}
