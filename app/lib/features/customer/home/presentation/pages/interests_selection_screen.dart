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

  static const Color _brand = Color(0xFFD32027);
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _border = Color(0xFFE5E7EB);

  static const int _minPick = 5;

  @override
  Widget build(BuildContext context) {
    final picked = _selectedInterests.length;
    final ready = picked >= _minPick;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: const Color(0xFF111827),
          shape: const Border(bottom: BorderSide(color: _border)),
          title: const Text(
            'تخصيص تجربتك',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _brand),
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ما الذي يهمّك؟',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'اختر خمسة تصنيفات على الأقل، لنعرض لك ما يناسبك',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  height: 1.8,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _progress(picked),
                            ],
                          ),
                        ),

                        Expanded(
                          child: _categories.isEmpty
                              ? _emptyCategories()
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 18, 20, 18),
                                  child: Wrap(
                                    spacing: 9,
                                    runSpacing: 9,
                                    children: _categories
                                        .map((c) => _chip(
                                            (c['name'] ?? '').toString()))
                                        .toList(),
                                  ),
                                ),
                        ),

                        // شريط الإجراء — مثبّت أسفل الشاشة
                        Container(
                          padding:
                              const EdgeInsets.fromLTRB(20, 14, 20, 20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: _border),
                            ),
                          ),
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  (ready && !_isSaving) ? _saveInterests : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _border,
                                disabledForegroundColor:
                                    const Color(0xFF9CA3AF),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      ready
                                          ? 'متابعة'
                                          : 'اختر $_minPick على الأقل',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// شريط تقدّم صغير — يبيّن كم بقي
  Widget _progress(int picked) {
    final ratio = (picked / _minPick).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: _border,
              valueColor: const AlwaysStoppedAnimation<Color>(_brand),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$picked / $_minPick',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: picked >= _minPick ? _brand : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _chip(String name) {
    final sel = _selectedInterests.contains(name);

    return GestureDetector(
      onTap: () => setState(() {
        sel ? _selectedInterests.remove(name) : _selectedInterests.add(name);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _brand.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? _brand : _border,
            width: sel ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sel) ...[
              const Icon(Icons.check_rounded, size: 14, color: _brand),
              const SizedBox(width: 5),
            ],
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? _brand : const Color(0xFF4A5468),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCategories() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined,
                size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'تعذّر جلب التصنيفات، حاول لاحقاً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
