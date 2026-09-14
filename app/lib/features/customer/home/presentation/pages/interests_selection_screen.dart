import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/core/routing/route_paths.dart';
import 'package:go_router/go_router.dart';

class InterestsSelectionScreen extends StatefulWidget {
  const InterestsSelectionScreen({super.key});

  @override
  State<InterestsSelectionScreen> createState() =>
      _InterestsSelectionScreenState();
}

class _InterestsSelectionScreenState extends State<InterestsSelectionScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  final List<String> _selectedInterests = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await supabase
          .from('store_categories')
          .select('name')
          .eq('is_visible', true);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ الدالة النهائية للحفظ بنظام الـ Upsert
  Future<void> _saveInterests() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // استخدام upsert يضمن تحديث الصف الحالي للعميل أو إنشاؤه إذا فُقد
      await supabase.from('profiles').upsert({
        'id': user.id, // المفتاح الأساسي للعميل
        'interests': _selectedInterests, // سيتم تخزينها كمصفوفة JSON
      });

      if (mounted) {
        // تأكيد أخير قبل الانتقال
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("تم حفظ اهتماماتك بنجاح"),
              backgroundColor: Colors.green),
        );
        context.go(RoutePaths.home);
      }
    } catch (e) {
      debugPrint("❌ فشل الحفظ: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الحفظ: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("تخصيص التجربة", style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD32027)))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ما هي المجالات التي تهمك؟",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  const Text("اختر 5 على الأقل لنقدم لك أفضل العروض",
                      style:
                          TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _categories.map((cat) {
                          final name = cat['name'];
                          final isSelected = _selectedInterests.contains(name);
                          return FilterChip(
                            label: Text(name,
                                style: const TextStyle(fontFamily: 'Cairo')),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                val
                                    ? _selectedInterests.add(name)
                                    : _selectedInterests.remove(name);
                              });
                            },
                            selectedColor:
                                const Color(0xFFD32027).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFFD32027),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32027),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_selectedInterests.length >= 5 && !_isSaving)
                          ? () => _saveInterests()
                          : null,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("حفظ ومتابعة (${_selectedInterests.length}/5)",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
