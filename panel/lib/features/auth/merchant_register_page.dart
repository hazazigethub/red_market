import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification_page.dart';
import 'package:red_market_core/red_market_core.dart';
import '../merchant/terms_page.dart';

class MerchantRegisterPage extends StatefulWidget {
  const MerchantRegisterPage({super.key});

  @override
  State<MerchantRegisterPage> createState() => _MerchantRegisterPageState();
}

class _MerchantRegisterPageState extends State<MerchantRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _ownerNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _freelanceController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _crNumberController = TextEditingController();

  bool _isTermsAccepted = false;
  /// إظهار كلمتي المرور معاً — فالغرض مقارنة ما كُتب
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _selectedStoreCategory;
  Uint8List? _crImageBytes;
  String? _crImageName;
  String? _crImageMime;

  /// شهادة الضريبة — اختيارية
  Uint8List? _vatImageBytes;
  String? _vatImageName;
  String? _vatImageMime;

  /// نوع الوثيقة: سجل تجاري أو وثيقة عمل حر
  bool _isFreelance = false;

  final ImagePicker _picker = ImagePicker();
  late final Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final v = await Supabase.instance.client
        .from('store_categories')
        .select('id, name');
    return List<Map<String, dynamic>>.from(v);
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _vatNumberController.dispose();
    _freelanceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _crNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickCrImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _crImageBytes = bytes;
      _crImageName = img.name;
      _crImageMime = img.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _pickVatImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _vatImageBytes = bytes;
      _vatImageName = img.name;
      _vatImageMime = img.mimeType ?? 'image/jpeg';
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isTermsAccepted) {
      _showError('يرجى الموافقة على الشروط والأحكام أولاً');
      return;
    }
    if (_crImageBytes == null) {
      _showError(_isFreelance
          ? 'صورة وثيقة العمل الحر مطلوبة'
          : 'صورة السجل التجاري مطلوبة');
      return;
    }
    if (_selectedStoreCategory == null) {
      _showError('يرجى اختيار تصنيف المتجر');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('كلمات المرور غير متطابقة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final String cleanPhone =
          _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      // البريد الحقيقي هوية المصادقة — ليعمل استرداد كلمة المرور
      final String email =
          _emailController.text.trim().toLowerCase();
      final String password = _passwordController.text.trim();

      // فحص مسبق — فالتسجيل المكرّر يفشل صامتاً في Supabase
      final avail = await supabase.rpc(
        'check_signup_availability',
        params: {'p_email': email, 'p_phone': cleanPhone},
      ) as Map<String, dynamic>;

      if (avail['email_taken'] == true) {
        _showError('هذا البريد مسجّل مسبقاً — سجّل دخولك أو استعد كلمة المرور');
        return;
      }
      if (avail['phone_taken'] == true) {
        _showError('رقم الجوال مسجّل بحساب آخر — سجّل دخولك أو استخدم رقماً غيره');
        return;
      }

      // 1) إنشاء الحساب — البيانات في metadata فلا جلسة قبل التأكيد
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'merchant',
          'full_name': _ownerNameController.text.trim(),
          'phone_number': cleanPhone,
        },
      );

      if (!mounted) return;

      // 2) الرفع وكتابة البيانات تُؤجَّل لما بعد التحقّق — فهي تتطلب جلسة
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            title: 'تأكيد بريدك',
            subtitle: 'أرسلنا رمزاً من ستة أرقام إلى',
            email: email,
            successMessage:
                'تم إنشاء حساب التاجر بنجاح — سجّل الدخول للمتابعة',
            onVerified: () => _completeMerchantSetup(cleanPhone, email),
          ),
        ),
      );

      if (done == true) {
        await supabase.auth.signOut();
        if (mounted) Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      _showError('خطأ في التسجيل: ${e.message}');
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// يُنفَّذ بعد تأكيد البريد — فالرفع والكتابة يتطلبان جلسة
  Future<void> _completeMerchantSetup(String cleanPhone, String email) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw 'انتهت الجلسة، حاول التسجيل مجدداً';

    // رفع السجل التجاري داخل مجلد المستخدم
    final ext = (_crImageName ?? 'cr.jpg').split('.').last;
    final fileName =
        '${user.id}/cr_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('merchants_docs').uploadBinary(
          fileName,
          _crImageBytes!,
          fileOptions: FileOptions(
              contentType: _crImageMime ?? 'image/jpeg', upsert: true),
        );
    final imageUrl =
        supabase.storage.from('merchants_docs').getPublicUrl(fileName);

    // شهادة الضريبة إن أرفقها
    String? vatUrl;
    if (_vatImageBytes != null) {
      try {
        final vExt = (_vatImageName ?? 'vat.jpg').split('.').last;
        final vName =
            '${user.id}/vat_${DateTime.now().millisecondsSinceEpoch}.$vExt';
        await supabase.storage.from('merchants_docs').uploadBinary(
              vName,
              _vatImageBytes!,
              fileOptions: FileOptions(
                  contentType: _vatImageMime ?? 'image/jpeg', upsert: true),
            );
        vatUrl = supabase.storage.from('merchants_docs').getPublicUrl(vName);
      } catch (e) {
        debugPrint('VAT upload error: $e');
      }
    }

    // نسخة الشروط المقبولة
    int latestTermsVersion = 0;
    try {
      final termsData = await supabase
          .from('terms_content')
          .select('version')
          .eq('type', 'merchant')
          .maybeSingle();
      latestTermsVersion = (termsData?['version'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    // الصفّ أنشأه المشغّل عند التسجيل — فنُحدّثه لا نُدرجه
    await supabase.from('profiles').update({
      'full_name': _ownerNameController.text.trim(),
      'phone_number': cleanPhone,
      'email_contact': email,
      'accepted_terms_version': latestTermsVersion,
    }).eq('id', user.id);

    await supabase.from('merchants').upsert({
      'id': user.id,
      'owner_id': user.id,
      'store_name': _nameController.text.trim(),
      'phone_number': cleanPhone,
      'email_contact': email,
      'owner_name': _ownerNameController.text.trim(),
      'cr_number': _isFreelance ? null : _crNumberController.text.trim(),
      'freelance_license_number':
          _isFreelance ? _freelanceController.text.trim() : null,
      'vat_number': _vatNumberController.text.trim().isEmpty
          ? null
          : _vatNumberController.text.trim(),
      'vat_certificate_url': vatUrl,
      'cr_image_url': imageUrl,
      'store_category_id': _selectedStoreCategory,
      'is_subscription_active': false,
      'is_banned': false,
      'is_permanent_ban': false,
    });

    // لا يُعتبر التسجيل ناجحاً إلا بوجود صف المتجر
    final check = await supabase
        .from('merchants')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (check == null) {
      throw 'تعذر إنشاء المتجر. تواصل مع الدعم الفني قبل محاولة التسجيل مجدداً.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== الترويسة =====
                      Text(
                        'تسجيل متجر جديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'انضم إلى رد ماركت واعرض ما لديك أمام آلاف العملاء',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 780;

                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _card(
                                title: 'بيانات المتجر',
                                icon: Icons.storefront_outlined,
                                children: [
                                  _field(_ownerNameController, 'اسم المالك',
                                      Icons.person_outline),
                                  const SizedBox(height: 14),
                                  _field(_nameController, 'اسم المتجر',
                                      Icons.storefront),
                                  const SizedBox(height: 14),
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _categoriesFuture,
                                    builder: (context, snap) {
                                      final items = snap.data ?? const [];
                                      return DropdownButtonFormField<String>(
                                        initialValue: _selectedStoreCategory,
                                        isExpanded: true,
                                        decoration: _decoration(
                                            'تصنيف المتجر',
                                            Icons.category_outlined),
                                        items: items
                                            .map((cat) =>
                                                DropdownMenuItem<String>(
                                                  value: cat['id'].toString(),
                                                  child: Text(
                                                      cat['name']
                                                              ?.toString() ??
                                                          '',
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ))
                                            .toList(),
                                        onChanged: (val) => setState(() =>
                                            _selectedStoreCategory = val),
                                      );
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              _card(
                                title: 'بيانات التواصل',
                                icon: Icons.contact_mail_outlined,
                                children: [
                                  _field(_phoneController, 'رقم الجوال',
                                      Icons.phone_android_rounded,
                                      keyboard: TextInputType.phone),
                                  const SizedBox(height: 14),
                                  _field(_emailController,
                                      'البريد الإلكتروني', Icons.email_outlined,
                                      keyboard: TextInputType.emailAddress),
                                ],
                              ),

                              const SizedBox(height: 16),

                              _card(
                                title: 'كلمة المرور',
                                icon: Icons.lock_outline_rounded,
                                children: [
                                  _field(_passwordController, 'كلمة المرور',
                                      Icons.lock_outline,
                                      obscure: _obscurePassword,
                                      suffix: _eyeButton()),
                                  const SizedBox(height: 14),
                                  _field(
                                      _confirmPasswordController,
                                      'تأكيد كلمة المرور',
                                      Icons.lock_reset_rounded,
                                      obscure: _obscurePassword,
                                      suffix: _eyeButton()),
                                ],
                              ),
                            ],
                          );

                          final right = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _card(
                                title: 'الوثائق النظامية',
                                icon: Icons.verified_user_outlined,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F2F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        _docTab('سجل تجاري', false),
                                        _docTab('عمل حر', true),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  if (_isFreelance)
                                    _field(
                                        _freelanceController,
                                        'رقم وثيقة العمل الحر',
                                        Icons.workspace_premium_outlined)
                                  else
                                    _field(_crNumberController,
                                        'رقم السجل التجاري',
                                        Icons.badge_outlined),

                                  const SizedBox(height: 14),

                                  _uploadTile(
                                    label: _crImageBytes == null
                                        ? (_isFreelance
                                            ? 'صورة وثيقة العمل الحر'
                                            : 'صورة السجل التجاري')
                                        : 'تم اختيار الصورة',
                                    done: _crImageBytes != null,
                                    icon: Icons.upload_file_rounded,
                                    onTap: _pickCrImage,
                                  ),
                                  if (_crImageBytes != null) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(_crImageBytes!,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 16),

                              _card(
                                title: 'الضريبة',
                                subtitle: 'اختياري',
                                icon: Icons.receipt_long_outlined,
                                children: [
                                  TextFormField(
                                    controller: _vatNumberController,
                                    keyboardType: TextInputType.number,
                                    decoration: _decoration('الرقم الضريبي',
                                        Icons.receipt_long_outlined),
                                  ),
                                  const SizedBox(height: 14),
                                  _uploadTile(
                                    label: _vatImageBytes == null
                                        ? 'شهادة الضريبة'
                                        : 'تم اختيار الشهادة',
                                    done: _vatImageBytes != null,
                                    icon: Icons.description_outlined,
                                    onTap: _pickVatImage,
                                  ),
                                  if (_vatImageBytes != null) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(_vatImageBytes!,
                                          height: 110,
                                          width: double.infinity,
                                          fit: BoxFit.cover),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 16),

                              _submitCard(),
                            ],
                          );

                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                left,
                                const SizedBox(height: 16),
                                right,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: left),
                              const SizedBox(width: 18),
                              Expanded(child: right),
                            ],
                          );
                        },
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// بطاقة الموافقة وإنشاء الحساب
  Widget _submitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: _isTermsAccepted,
                onChanged: (v) =>
                    setState(() => _isTermsAccepted = v ?? false),
                activeColor: AppColors.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              const Text('أوافق على ', style: TextStyle(fontSize: 13)),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsPage()),
                ),
                child: Text(
                  'الشروط والأحكام',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('إنشاء الحساب',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 4),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'لديك حساب؟ سجّل الدخول',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة تجمع حقولاً متصلة
  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.brand, size: 17),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  /// زر رفع ملف
  Widget _uploadTile({
    required String label,
    required bool done,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: done
              ? Colors.green.withValues(alpha: 0.05)
              : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? Colors.green.withValues(alpha: 0.35)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : icon,
              size: 19,
              color: done ? Colors.green : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: done ? FontWeight.bold : FontWeight.normal,
                  color: done ? Colors.green.shade800 : Colors.grey.shade700,
                ),
              ),
            ),
            if (!done)
              Icon(Icons.add_rounded,
                  size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// تنسيق موحّد للحقول
  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Widget _docTab(String label, bool freelance) {
    final on = _isFreelance == freelance;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isFreelance = freelance),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
              color: on ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  /// مخفي ⇒ عين مشطوبة · ظاهر ⇒ عين
  Widget _eyeButton() {
    return IconButton(
      onPressed: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        size: 19,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboard, Widget? suffix}) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: _decoration(label, icon, suffix: suffix),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
    );
  }
}
