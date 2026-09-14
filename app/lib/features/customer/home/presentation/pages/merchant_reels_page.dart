import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/features/customer/home/presentation/pages/reels_page.dart';
import 'package:red_market_core/red_market_core.dart';

class MerchantReelsPage extends StatefulWidget {
  final String merchantId;
  const MerchantReelsPage({super.key, required this.merchantId});

  @override
  State<MerchantReelsPage> createState() => _MerchantReelsPageState();
}

class _MerchantReelsPageState extends State<MerchantReelsPage> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFD32027);
  List<Map<String, dynamic>> _reels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  Future<void> _fetchReels() async {
    try {
      final data = await supabase
          .from('reels')
          .select('*, merchants:merchant_id(store_name, logo_url)')
          .eq('merchant_id', widget.merchantId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reels = (data as List).map((r) {
            final merchant = r['merchants'];
            return {
              ...Map<String, dynamic>.from(r),
              'merchant_name': merchant?['store_name'] ?? '',
              'merchant_logo': merchant?['logo_url'] ?? '',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    if (_reels.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: brandRed,
            title: const Text("فيديوهات المتجر",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            centerTitle: true,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context)),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline,
                    size: 60, color: Colors.grey.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                const Text("لا توجد ريلز لهذا المتجر",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ تحويل مباشر وفتح صفحة الريلز
    final reelModels = _reels
        .map((r) => ReelModel(
              id: r['id'].toString(),
              merchantId: r['merchant_id'].toString(),
              merchantName: r['merchant_name'] ?? '',
              merchantProfileImage: r['merchant_logo'] ?? '',
              videoUrl: r['video_url'] ?? '',
              title: r['title'] ?? '',
              description: r['description'] ?? '',
              thumbnailUrl: r['thumbnail_url'] ?? '',
              likesCount: r['likes_count'] ?? 0,
              commentsCount: r['comments_count'] ?? 0,
              productId: r['product_id']?.toString(),
            ))
        .toList();

    return ReelsPage(reels: reelModels);
  }
}
