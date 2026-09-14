import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:go_router/go_router.dart';

class CustomerInterestsPage extends StatefulWidget {
  const CustomerInterestsPage({super.key});

  @override
  State<CustomerInterestsPage> createState() => _CustomerInterestsPageState();
}

class _CustomerInterestsPageState extends State<CustomerInterestsPage> {
  final supabase = Supabase.instance.client;
  List<String> _allCategories = [];
  List<String> _selectedInterests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final categoriesData = await supabase
          .from('store_categories')
          .select('name')
          .eq('is_visible', true);

      final profileData = await supabase
          .from('profiles')
          .select('interests')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _allCategories = List<Map<String, dynamic>>.from(categoriesData)
              .map((e) => e['name'].toString())
              .toList();

          if (profileData != null && profileData['interests'] != null) {
            final List<dynamic> saved = profileData['interests'];
            _selectedInterests = saved.map((e) => e.toString()).toList();
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في جلب البيانات: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة للتحديث التلقائي في الخلفية عند كل ضغطة
  Future<void> _autoUpdateInterests(List<String> newInterests) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('profiles').update({
        'interests': newInterests,
      }).eq('id', user.id);
    } catch (e) {
      debugPrint("خطأ في التحديث التلقائي: $e");
      // ملاحظة: الخطأ 54001 غالباً بسبب Trigger في قاعدة البيانات نفسها
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
          title: const Text("اهتماماتي",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32027)))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: _allCategories.length,
                itemBuilder: (context, index) {
                  final category = _allCategories[index];
                  final isSelected = _selectedInterests.contains(category);

                  return InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedInterests.remove(category);
                        } else {
                          _selectedInterests.add(category);
                        }
                      });
                      // تحديث السوبابيس فوراً
                      _autoUpdateInterests(_selectedInterests);
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFD32027) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          )
                        ],
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD32027)
                                : Colors.grey.shade200,
                            width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                category,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
