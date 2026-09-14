import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeBanners extends StatelessWidget {
  final PageController bannerController;
  final PageController smallBannerController;

  const HomeBanners({
    super.key,
    required this.bannerController,
    required this.smallBannerController,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Column(
      children: [
        // Main Wide Banner
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('banners')
              .stream(primaryKey: ['id']).order('created_at'),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return _buildPlaceholder();
            final active = snapshot.data!
                .where(
                    (b) => b['banner_type'] == 'wide' && b['is_active'] == true)
                .toList();
            if (active.isEmpty) return _buildPlaceholder();
            return SizedBox(
              height: 160,
              child: PageView.builder(
                controller: bannerController,
                itemCount: 10000,
                itemBuilder: (context, index) {
                  final b = active[index % active.length];
                  return _buildBannerItem(b['image_url']);
                },
              ),
            );
          },
        ),
        // Small Banners Row
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('banners')
              .stream(primaryKey: ['id']).order('created_at'),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const SizedBox.shrink();
            final small = snapshot.data!
                .where((b) =>
                    b['banner_type'] == 'small' && b['is_active'] == true)
                .toList();
            if (small.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 120,
              child: PageView.builder(
                controller: smallBannerController,
                itemCount: 10000,
                itemBuilder: (context, index) {
                  final b = small[index % small.length];
                  return _buildBannerItem(b['image_url'], isSmall: true);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBannerItem(String url, {bool isSmall = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 4, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmall ? 12 : 15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmall ? 12 : 15),
        child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
      height: 140,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
              colors: [Color(0xFFD32027), Color(0xFFE62E04)])),
      child: const Center(
          child: Text(" رد ماركت ",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'))));
}
