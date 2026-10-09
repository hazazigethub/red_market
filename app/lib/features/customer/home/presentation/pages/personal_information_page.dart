import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController(text: "********");

  String? _avatarUrl;
  bool _isLoading = true;

  static const Color brandRed = Color(0xFFD32027);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // ✅ جلب رقم الجوال من profiles
      final profileData = await supabase
          .from('profiles')
          .select('phone_number')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        _usernameController.text = user.userMetadata?['full_name'] ?? "";
        _emailController.text = user.email ?? "";
        _avatarUrl = user.userMetadata?['avatar_url'];

        // ✅ رقم الجوال من profiles
        final phone = profileData?['phone_number'] ?? "";
        _phoneController.text = phone;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_avatar.$fileExt';
      final bytes = await image.readAsBytes();

      // ✅ رفع الصورة
      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // ✅ الحصول على الرابط العام
      final String publicUrl =
          supabase.storage.from('avatars').getPublicUrl(fileName);

      // ✅ تحديث رابط الصورة في Metadata
      await supabase.auth.updateUser(UserAttributes(
        data: {'avatar_url': publicUrl},
      ));

      setState(() {
        _avatarUrl = publicUrl;
        _isLoading = false;
      });

      _showSnackBar("تم تحديث الصورة الشخصية بنجاح ✅", Colors.green);
    } catch (e, stack) {
      debugPrint("Upload error: $e\n$stack");
      setState(() => _isLoading = false);
      _showSnackBar("فشل رفع الصورة: $e", Colors.red);
    }
  }

  /// تغيير رقم الجوال — يُتحقق برمز يُرسل إلى بريد الحساب
  void _showChangePhoneSheet() {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool codeSent = false;
    bool busy = false;

    String cleanPhone() =>
        phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

    Future<void> sendCode(StateSetter setSheet) async {
      final phone = cleanPhone();
      if (!RegExp(r'^05\d{8}$').hasMatch(phone)) {
        _showSnackBar("أدخل رقماً صحيحاً بصيغة 05xxxxxxxx", Colors.orange);
        return;
      }
      if (phone == _phoneController.text.trim()) {
        _showSnackBar("هذا هو رقمك الحالي", Colors.orange);
        return;
      }
      setSheet(() => busy = true);
      try {
        await supabase.auth.signInWithOtp(
          email: _emailController.text.trim(),
          shouldCreateUser: false,
        );
        setSheet(() => codeSent = true);
        _showSnackBar("أُرسل الرمز إلى ${_emailController.text}", Colors.green);
      } catch (e) {
        debugPrint('Send phone code error: $e');
        _showSnackBar("تعذر إرسال الرمز، حاول بعد قليل", Colors.red);
      } finally {
        setSheet(() => busy = false);
      }
    }

    Future<void> confirm(BuildContext sheetContext, StateSetter setSheet) async {
      if (!formKey.currentState!.validate()) return;
      final phone = cleanPhone();
      setSheet(() => busy = true);
      try {
        // ١) التحقق من الرمز
        await supabase.auth.verifyOTP(
          email: _emailController.text.trim(),
          token: codeController.text.trim(),
          type: OtpType.email,
        );

        // ٢) تحديث الرقم
        final uid = supabase.auth.currentUser?.id;
        if (uid == null) throw Exception('no session');
        await supabase
            .from('profiles')
            .update({'phone_number': phone}).eq('id', uid);

        _phoneController.text = phone;
        if (sheetContext.mounted) Navigator.pop(sheetContext);
        _showSnackBar("تم تغيير رقم الجوال بنجاح ✅", Colors.green);
      } on AuthException catch (e) {
        debugPrint('Verify phone code error: ${e.message}');
        _showSnackBar("الرمز غير صحيح أو منتهي الصلاحية", Colors.red);
      } on PostgrestException catch (e) {
        debugPrint('Update phone error: ${e.message}');
        _showSnackBar(
            e.code == '23505'
                ? "هذا الرقم مسجّل في حساب آخر"
                : "تعذر تحديث الرقم",
            Colors.red);
      } catch (e) {
        debugPrint('Change phone error: $e');
        _showSnackBar("حدث خطأ أثناء التحديث", Colors.red);
      } finally {
        if (mounted) setSheet(() => busy = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("تغيير رقم الجوال",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: phoneController,
                  enabled: !codeSent,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    labelText: "رقم الجوال الجديد",
                    hintText: "05xxxxxxxx",
                    labelStyle:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandRed)),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "سنرسل رمز تحقق إلى\n${_emailController.text}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13, height: 1.7),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy ? null : () => sendCode(setSheet),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: brandRed,
                        side: const BorderSide(color: brandRed),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: Text(
                        busy && !codeSent
                            ? "جاري الإرسال..."
                            : codeSent
                                ? "إعادة إرسال الرمز"
                                : "إرسال الرمز",
                        style: const TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
                if (codeSent) ...[
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: "رمز التحقق",
                      labelStyle:
                          const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: brandRed)),
                    ),
                    validator: (v) => (v ?? '').trim().length == 6
                        ? null
                        : "أدخل الرمز المكوّن من ستة أرقام",
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: busy ? null : () => confirm(context, setSheet),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text("تأكيد التغيير",
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    // الخانتان تتشاركان الحالة — فالغرض مقارنة ما كُتب
    final obscure = ValueNotifier<bool>(true);
    final codeController = TextEditingController();
    bool codeSent = false;
    bool sending = false;

    // يرسل رمز التحقق إلى بريد الحساب
    Future<void> sendCode(StateSetter setSheet) async {
      setSheet(() => sending = true);
      try {
        await supabase.auth.reauthenticate();
        setSheet(() => codeSent = true);
        _showSnackBar("أُرسل الرمز إلى ${_emailController.text}", Colors.green);
      } catch (e) {
        debugPrint('Reauthenticate error: $e');
        _showSnackBar("تعذر إرسال الرمز، حاول بعد قليل", Colors.red);
      } finally {
        setSheet(() => sending = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
       builder: (context, setSheet) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: const Border(top: BorderSide(color: brandRed, width: 1.5)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              const Text("تحديث كلمة المرور",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 20),
              // ===== رمز التحقق عبر البريد =====
              Text(
                "سنرسل رمز تحقق إلى\n${_emailController.text}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, height: 1.7),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: sending ? null : () => sendCode(setSheet),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: brandRed,
                      side: const BorderSide(color: brandRed),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Text(
                      sending
                          ? "جاري الإرسال..."
                          : codeSent
                              ? "إعادة إرسال الرمز"
                              : "إرسال الرمز",
                      style: const TextStyle(fontFamily: 'Cairo')),
                ),
              ),
              if (codeSent) ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: "رمز التحقق",
                    labelStyle:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    counterText: '',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandRed)),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().length == 6 ? null : "أدخل الرمز المكوّن من ستة أرقام",
                ),
              ],
              const SizedBox(height: 15),
              _buildSheetTextField(
                  newPwdController, "كلمة المرور الجديدة", true,
                  obscure: obscure),
              const SizedBox(height: 15),
              _buildSheetTextField(
                  confirmPwdController, "تأكيد كلمة المرور الجديدة", true,
                  obscure: obscure),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: brandRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    if (!codeSent) {
                      _showSnackBar("أرسل رمز التحقق أولاً", Colors.orange);
                      return;
                    }
                    if (formKey.currentState!.validate()) {
                      if (newPwdController.text != confirmPwdController.text) {
                        _showSnackBar("كلمات المرور غير متطابقة", Colors.red);
                        return;
                      }
                      try {
                        await supabase.auth.updateUser(UserAttributes(
                          password: newPwdController.text.trim(),
                          nonce: codeController.text.trim(),
                        ));
                        if (context.mounted) Navigator.pop(context);
                        _showSnackBar(
                            "تم تحديث كلمة المرور بنجاح ✅", Colors.green);
                      } on AuthException catch (e) {
                        debugPrint('Update password error: ${e.message}');
                        _showSnackBar("الرمز غير صحيح أو منتهي الصلاحية",
                            Colors.red);
                      } catch (e) {
                        _showSnackBar("حدث خطأ أثناء التحديث", Colors.red);
                      }
                    }
                  },
                  child: const Text("تحديث كلمة المرور",
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("المعلومات الشخصية",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileImageSection(),
                          const SizedBox(height: 40),
                          _buildFieldLabel("اسم المستخدم الكامل"),
                          _buildTextField(
                              _usernameController, Icons.person_outline),
                          const SizedBox(height: 25),
                          _buildFieldLabel("رقم الجوال"),
                          _buildPhoneField(_phoneController),
                          const SizedBox(height: 25),
                          _buildFieldLabel("البريد الإلكتروني"),
                          _buildEmailField(_emailController),
                          const SizedBox(height: 25),
                          _buildFieldLabel("إدارة الحماية"),
                          _buildPasswordField(),
                        ],
                      ),
                    ),
                  ),
                  _buildSaveButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: brandRed.withValues(alpha: 0.4), width: 3)),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[200],
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 50, color: brandRed)
                  : null,
            ),
          ),
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  const BoxDecoration(color: brandRed, shape: BoxShape.circle),
              child:
                  const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: _showChangePasswordSheet,
      child: IgnorePointer(
        child: _buildTextField(_passwordController, Icons.lock_outline,
            isPassword: true,
            suffix: const Icon(Icons.edit_outlined, size: 18, color: brandRed)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveProfileData,
          style: ElevatedButton.styleFrom(
              backgroundColor: brandRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 0),
          child: const Text("حفظ البيانات",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo')),
        ),
      ),
    );
  }

  Future<void> _saveProfileData() async {
    if (_usernameController.text.trim().isEmpty) {
      _showSnackBar("الاسم لا يمكن أن يكون فارغاً", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final newName = _usernameController.text.trim();
      final user = supabase.auth.currentUser;

      await supabase.auth.updateUser(UserAttributes(
        data: {'full_name': newName},
      ));

      // ✅ تحديث الاسم في profiles أيضاً ليظهر في التعليقات وبقية الأماكن
      if (user != null) {
        await supabase.from('profiles').update({
          'full_name': newName,
          'name': newName,
        }).eq('id', user.id);
      }

      _showSnackBar("تم تحديث الاسم بنجاح ✅", Colors.green);
    } catch (e) {
      debugPrint('Save profile error: $e');
      _showSnackBar("حدث خطأ أثناء الحفظ", Colors.red);
    }
    setState(() => _isLoading = false);
  }

  Widget _buildSheetTextField(
      TextEditingController controller, String label, bool isPwd,
      {ValueNotifier<bool>? obscure}) {
    final notifier = obscure ?? ValueNotifier<bool>(isPwd);

    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, hidden, _) => TextFormField(
        controller: controller,
        obscureText: isPwd && hidden,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          // مخفي ⇒ عين مشطوبة · ظاهر ⇒ عين
          suffixIcon: isPwd
              ? IconButton(
                  onPressed: () => notifier.value = !hidden,
                  tooltip:
                      hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: Colors.grey,
                  ),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: brandRed)),
        ),
        validator: (val) => passwordError(val ?? ''),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon,
      {bool isPassword = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildPhoneField(TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      textAlign: TextAlign.left,
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.phone_android, color: Colors.grey, size: 22),
        suffixIcon: TextButton(
          onPressed: _showChangePhoneSheet,
          child: const Text("تغيير",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: brandRed,
                  fontWeight: FontWeight.bold)),
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildEmailField(TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.alternate_email_rounded, color: Colors.grey, size: 22),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color));
  }
}

/// ٨ خانات على الأقل، مع حرف كبير وصغير ورقم ورمز
String? passwordError(String pw) {
  if (pw.length < 8) return 'كلمة المرور يجب أن تكون 8 خانات على الأقل';
  if (!RegExp(r'[a-z]').hasMatch(pw)) {
    return 'أضف حرفاً إنجليزياً صغيراً على الأقل';
  }
  if (!RegExp(r'[A-Z]').hasMatch(pw)) {
    return 'أضف حرفاً إنجليزياً كبيراً على الأقل';
  }
  if (!RegExp(r'[0-9]').hasMatch(pw)) return 'أضف رقماً على الأقل';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) {
    return 'أضف رمزاً مثل ! أو @ أو #';
  }
  return null;
}
