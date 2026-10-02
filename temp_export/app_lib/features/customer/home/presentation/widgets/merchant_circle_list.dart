import 'package:flutter/material.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:red_market/features/customer/home/presentation/pages/store_details_page.dart';

class MerchantCircleList extends StatelessWidget {
  final List<MerchantModel> merchants;

  const MerchantCircleList({super.key, required this.merchants});

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            "اكتشف المتـاجر",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: merchants.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildSmallVerticalCard(context, merchants[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSmallVerticalCard(BuildContext context, MerchantModel merchant) {
    return GestureDetector(
      onTap: () {
        // ✅ التعديل هنا: تمرير merchantId بدلاً من merchant ككائن
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoreDetailsPage(merchantId: merchant.id),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(left: 12, bottom: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD32027).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // 1. اللوجو والاسم
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD32027), width: 1.5),
                image: DecorationImage(
                    image: NetworkImage(merchant.logoUrl), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              merchant.storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'),
            ),

            const SizedBox(height: 10),

            // 2. معرض الصور الديناميكي
            if (merchant.showcaseImages.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    // الصورة الكبيرة
                    AspectRatio(
                      aspectRatio: 1 / 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          merchant.showcaseImages[0],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // الصورتين الصغيرتين
                    if (merchant.showcaseImages.length > 1)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  merchant.showcaseImages[1],
                                  fit: BoxFit.cover,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: merchant.showcaseImages.length > 2
                                    ? Image.network(
                                        merchant.showcaseImages[2],
                                        fit: BoxFit.cover,
                                        height: double.infinity,
                                      )
                                    : Container(color: Colors.grey.shade50),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
