import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import '../widgets/product_card.dart';

class FlashSalesPage extends StatefulWidget {
  const FlashSalesPage({super.key});

  @override
  State<FlashSalesPage> createState() => _FlashSalesPageState();
}

class _FlashSalesPageState extends State<FlashSalesPage> {
  final supabase = Supabase.instance.client;
  List<ProductModel> _flashProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFlashProducts();
  }

  Future<void> _fetchFlashProducts() async {
    try {
      final now = DateTime.now().toIso8601String();
      // جلب العروض التي لم تنتهِ صلاحيتها وموسومة كعرض 24 ساعة
      final data = await supabase
          .from('products')
          .select()
          .eq('is_flash_sale', true)
          .gt('flash_sale_expiry', now) // أكبر من الوقت الحالي
          .eq('is_available', true);

      if (mounted) {
        setState(() {
          _flashProducts =
              (data as List).map((p) => ProductModel.fromJson(p)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("عروض الـ 24 ساعة",
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: const Color(0xFFD32027),
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32027)))
            : _flashProducts.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 15,
                            childAspectRatio: 0.7),
                    itemCount: _flashProducts.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: _flashProducts[index]),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا توجد عروض نشطة حالياً",
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
