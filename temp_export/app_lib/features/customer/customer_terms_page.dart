import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market/app/app.dart';
import 'package:go_router/go_router.dart'; // ✅ أضفنا هذا للتنقل
import 'package:red_market/core/routing/route_paths.dart'; // ✅ أضفنا هذا للمسارات

class CustomerTermsPage extends ConsumerStatefulWidget {
  // ✅ التغيير الأول: إضافة البارامترات لاستقبال البيانات من الـ Router
  final String? content;
  final int? version;
  final bool isMandatory;

  const CustomerTermsPage({
    super.key,
    this.content,
    this.version,
    this.isMandatory = false, // افتراضياً false للعرض العادي من الإعدادات
  });

  @override
  ConsumerState<CustomerTermsPage> createState() => _CustomerTermsPageState();
}

class _CustomerTermsPageState extends ConsumerState<CustomerTermsPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = true;
  String _currentContent = "";

  @override
  void initState() {
    super.initState();
    // ✅ التغيير الثاني: إذا كانت البيانات قادمة من الـ Router نستخدمها مباشرة، وإلا نجلبها
    if (widget.content != null) {
      _currentContent = widget.content!;
      _controller.text = _currentContent;
      _isLoading = false;
    } else {
      _fetchTerms();
    }
  }

  Future<void> _fetchTerms() async {
    try {
      final data = await Supabase.instance.client
          .from('terms_content')
          .select('content')
          .eq('type', 'customer')
          .single();

      setState(() {
        _currentContent = data['content'] ?? "";
        _controller.text = _currentContent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching terms: $e");
    }
  }

  // ✅ التغيير الثالث: دالة قبول الشروط للمستخدم العادي
  Future<void> _acceptTerms() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // تحديث نسخة الشروط المقبولة في بروفايل المستخدم
      await Supabase.instance.client
          .from('profiles')
          .update({'accepted_terms_version': widget.version}).eq('id', userId);

      if (!mounted) return;

      // الانتقال للهوم بعد القبول
      context.go(RoutePaths.home);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("حدث خطأ أثناء قبول الشروط")),
      );
    }
  }

  Future<void> _saveTerms() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc('increment_terms_version', params: {
        'term_type': 'customer',
        'new_content': _controller.text,
      });

      setState(() {
        _currentContent = _controller.text;
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("تم اعتماد الشروط الجديدة وفرضها على الجميع")),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("حدث خطأ أثناء الحفظ")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(userRoleProvider);
    final bool isSuperAdmin = userRole == 'super_admin';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ✅ منع الرجوع للخلف إذا كانت الشروط إجبارية
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isMandatory,
          elevation: 0,
          title: const Text("شروط وأحكام العميل",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          centerTitle: true,
          actions: [
            if (isSuperAdmin && !_isEditing)
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                onPressed: () => setState(() => _isEditing = true),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                // ✅ تم تغيير SingleChildScrollView لـ Column لإضافة الزر في الأسفل
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("اتفاقية استخدام العميل",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo')),
                          const SizedBox(height: 15),
                          _isEditing
                              ? TextField(
                                  controller: _controller,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder()),
                                )
                              : Text(
                                  _currentContent,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.8,
                                      fontFamily: 'Cairo',
                                      color: Colors.black87),
                                ),
                          if (_isEditing) ...[
                            const SizedBox(height: 20),
                            _buildAdminEditButtons(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ✅ التغيير الرابع: إضافة زر القبول الإجباري للمستخدم
                  if (widget.isMandatory)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _acceptTerms,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                                0xFFD32027), // اللون الأحمر الخاص بك
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("أوافق على الشروط والأحكام",
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 16)),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildAdminEditButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saveTerms,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("اعتماد وفرض الشروط",
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() {
              _isEditing = false;
              _controller.text = _currentContent;
            }),
            child: const Text("إلغاء التعديل",
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ),
      ],
    );
  }
}
