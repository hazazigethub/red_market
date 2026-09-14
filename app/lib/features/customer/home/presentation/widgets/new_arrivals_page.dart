import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// تأكد من استخدام اسم المشروع الخاص بك (RedOcean)
import 'package:red_market_core/red_market_core.dart';
import '../widgets/product_card.dart';

class NewArrivalsPage extends StatefulWidget {
  const NewArrivalsPage({super.key});

  @override
  State<NewArrivalsPage> createState() => _NewArrivalsPageState();
}

class _NewArrivalsPageState extends State<NewArrivalsPage> {
  final supabase = Supabase.instance.client;
  List<ProductModel> _allNewProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNewArrivals();
  }

  Future<void> _fetchNewArrivals() async {
    try {
      final fiveDaysAgo =
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String();

      final data = await supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .gte('created_at', fiveDaysAgo)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allNewProducts =
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
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("مضافة حديثاً (آخر 5 أيام)",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32027)))
            : _allNewProducts.isEmpty
                ? const Center(
                    child: Text("لا توجد عروض جديدة حالياً",
                        style: TextStyle(fontFamily: 'Cairo')))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _allNewProducts.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: _allNewProducts[index]),
                  ),
      ),
    );
  }
}
