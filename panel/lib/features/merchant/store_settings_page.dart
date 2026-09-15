import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login_page.dart';

class StoreSettingsPage extends StatefulWidget {
  final String? merchantId;
  const StoreSettingsPage({super.key, this.merchantId});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final _ownerNameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _crNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _emailController = TextEditingController();

  String? _logoUrl;
  String? _crImageUrl;
  String? _categoryName;
  String? _vatNumber;
  String? _freelanceNumber;
  bool _isLoading = true;
  bool _isEditing = false;
  /// إظهار الرمز داخل بطاقة الإعدادات
  bool _obscurePassword = true;

  static const Color brandColor = Color(0xFFD32027);
  static const Color primaryBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  void _showActivationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تفعيل المتجر ⚠️",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: brandColor)),
          content: const Text(
            "أهلاً بك في رد ماركت! لتفعيل متجرك وإظهار عروضك أمام العملاء، "
            "يرجى رفع شعار المتجر وإضافة رابطه.",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isEditing = true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandColor),
              child: const Text("ابدأ الآن",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStoreData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final merchantData = await supabase
          .from('merchants')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (merchantData != null && mounted) {
        // ✅ جلب اسم التصنيف
        String? categoryName;
        if (merchantData['store_category_id'] != null) {
          final catData = await supabase
              .from('store_categories')
              .select('name')
              .eq('id', merchantData['store_category_id'])
              .maybeSingle();
          categoryName = catData?['name'];
        }

        setState(() {
          _storeNameController.text = merchantData['store_name'] ?? "";
          _descriptionController.text = merchantData['store_description'] ?? "";
          _logoUrl =
              _formatImageUrl(merchantData['logo_url'], 'merchant-assets');
          _crImageUrl =
              _formatImageUrl(merchantData['cr_image_url'], 'merchants_docs');
          _phoneController.text = merchantData['phone_number'] ?? "";
          _crNumberController.text = merchantData['cr_number'] ?? "";
          _ownerNameController.text = merchantData['owner_name'] ?? "";
          _vatNumber = merchantData['vat_number']?.toString();
          _freelanceNumber =
              merchantData['freelance_license_number']?.toString();
          _storeUrlController.text = merchantData['store_url'] ?? "";
          _categoryName = categoryName;
          _emailController.text = merchantData['email_contact'] ?? "";
        });

        if ((merchantData['logo_url'] == null ||
                merchantData['logo_url'].toString().isEmpty) ||
            (merchantData['store_url'] == null ||
                merchantData['store_url'].toString().isEmpty)) {
          Future.delayed(Duration.zero, () => _showActivationDialog());
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _formatImageUrl(dynamic url, String bucket) {
    if (url == null || url.toString().isEmpty) return null;
    if (url.toString().startsWith('http')) return url.toString();
    return supabase.storage.from(bucket).getPublicUrl(url.toString());
  }

  Future<void> _pickImage(bool isLogo) async {
    if (!_isEditing) return;
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final bucket = isLogo ? 'merchant-assets' : 'merchants_docs';
      final fileName = '${isLogo ? "logo" : "cr"}_$userId.jpg';
      await supabase.storage.from(bucket).uploadBinary(
          fileName, await image.readAsBytes(),
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final String publicUrl =
          supabase.storage.from(bucket).getPublicUrl(fileName);

      await supabase.from('merchants').update(
          {isLogo ? 'logo_url' : 'cr_image_url': publicUrl}).eq('id', userId);

      setState(() {
        if (isLogo) {
          _logoUrl = publicUrl;
        } else {
          _crImageUrl = publicUrl;
        }
      });
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ طلب حذف الحساب — تعطيل فوري وحذف بعد 30 يوماً
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("طلب حذف الحساب",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "عند تقديم الطلب:",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "• يُعطَّل حسابك فوراً وتختفي عروضك عن العملاء\n"
                  "• تُحذف بياناتك نهائياً بعد 30 يوماً\n"
                  "• يمكنك التراجع بالدخول خلال هذه المدة\n"
                  "• لا استرداد لما تبقّى من اشتراكك",
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 13, height: 2.0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                _requestDeletion();
              },
              child: const Text("تأكيد الطلب",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// يستدعي دالة قاعدة البيانات لتسجيل الطلب
  Future<void> _requestDeletion() async {
    try {
      final res = await supabase.rpc('request_account_deletion');
      final map = Map<String, dynamic>.from(res as Map);

      if (!mounted) return;

      if (map['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "تم استلام طلبك. سيُحذف حسابك بعد 30 يوماً، ويمكنك التراجع بالدخول خلال هذه المدة.",
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));

        await Future.delayed(const Duration(seconds: 3));
        await supabase.auth.signOut();

        if (!mounted) return;
        // إخراج كامل: مسح كل الشاشات والعودة لصفحة الدخول
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(map['error']?.toString() ?? "تعذر تنفيذ الطلب",
              style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint("Delete request error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تعذر تنفيذ الطلب، حاول مجدداً",
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandColor))
            : RefreshIndicator(
                color: brandColor,
                onRefresh: _loadStoreData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),

                      GridView.extent(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        maxCrossAxisExtent: 260,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1,
                        children: [
                          _buildSquareTile(isDark, Icons.storefront_outlined,
                              "الاسم", _storeNameController),
                          _buildSquareTile(isDark, Icons.person_outline,
                              "اسم المالك", _ownerNameController),
                          _buildSquareTile(isDark, Icons.phone_android_outlined,
                              "الهاتف", _phoneController,
                              keyboard: TextInputType.phone),
                          if (_freelanceNumber != null &&
                              _freelanceNumber!.isNotEmpty)
                            _readOnlyTile(
                                isDark,
                                Icons.workspace_premium_outlined,
                                "وثيقة العمل الحر",
                                _freelanceNumber!)
                          else
                            _readOnlyTile(isDark, Icons.badge_outlined,
                                "السجل التجاري", _crNumberController.text),
                          _readOnlyTile(isDark, Icons.receipt_long_outlined,
                              "الرقم الضريبي", _vatNumber ?? "—"),
                          _buildSquareTile(isDark, Icons.lock_open_outlined,
                              "الرمز", _passwordController,
                              isPass: true),
                          _buildSquareTile(isDark, Icons.email_outlined,
                              "الإيميل", _emailController,
                              keyboard: TextInputType.emailAddress),
                          if (_categoryName != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.category_outlined,
                                            color: brandColor, size: 28),
                                        const SizedBox(height: 8),
                                        const Text("التصنيف",
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11,
                                                color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text(_categoryName!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildWideTile(isDark, Icons.info_outline, "وصف المتجر",
                          _descriptionController,
                          maxLines: 6),
                      const SizedBox(height: 12),
                      _buildWideTile(isDark, Icons.link_rounded, "رابط المتجر",
                          _storeUrlController),
                      const SizedBox(height: 12),
                      _buildImageTile(isDark, "صورة السجل التجاري"),
                      const SizedBox(height: 32),
                      _buildActionButton(),
                      const SizedBox(height: 16),

                      // ✅ زر حذف الحساب
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _showDeleteAccountDialog,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.delete_forever_outlined,
                              color: Colors.red),
                          label: const Text("حذف الحساب",
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.red)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(true),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: brandColor, width: 2)),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                  child: _logoUrl == null
                      ? const Icon(Icons.add_a_photo_outlined,
                          color: brandColor, size: 28)
                      : null,
                ),
              ),
              if (_isEditing)
                CircleAvatar(
                    radius: 16,
                    backgroundColor: brandColor,
                    child:
                        const Icon(Icons.edit, size: 16, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  /// حقل للقراءة فقط — لا يُعدَّل إلا عبر الدعم
  Widget _readOnlyTile(
      bool isDark, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 26),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? "—" : value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text("عبر الدعم",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 9.5,
                      color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareTile(bool isDark, IconData icon, String label,
      TextEditingController controller,
      {bool isPass = false, TextInputType keyboard = TextInputType.text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            _isEditing ? Border.all(color: brandColor.withValues(alpha: 0.5)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: brandColor, size: 28),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
          TextField(
            controller: controller,
            enabled: _isEditing,
            obscureText: isPass && _obscurePassword,
            textAlign: TextAlign.center,
            keyboardType: keyboard,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black),
            decoration:
                const InputDecoration(isDense: true, border: InputBorder.none),
          ),
          // مخفي ⇒ عين مشطوبة · ظاهر ⇒ عين
          if (isPass)
            InkWell(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 17,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWideTile(bool isDark, IconData icon, String label,
      TextEditingController controller,
      {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            _isEditing ? Border.all(color: brandColor.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: brandColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                TextField(
                  controller: controller,
                  enabled: _isEditing,
                  maxLines: maxLines,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                      isDense: true, border: InputBorder.none),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(bool isDark, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? Colors.black26 : const Color(0xFFF5F7FA),
                image: _crImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_crImageUrl!), fit: BoxFit.contain)
                    : null,
                border: Border.all(
                    color: _isEditing
                        ? brandColor.withValues(alpha: 0.5)
                        : Colors.transparent),
              ),
              child: (_crImageUrl == null && _isEditing)
                  ? const Icon(Icons.add_photo_alternate_outlined,
                      color: brandColor, size: 40)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: () async {
        if (!_isEditing) {
          setState(() => _isEditing = true);
        } else {
          setState(() => _isLoading = true);
          try {
            final userId = supabase.auth.currentUser!.id;
            await Future.wait([
              supabase.from('profiles').update({
                'full_name': _storeNameController.text.trim(),
                'phone_number': _phoneController.text.trim(),
              }).eq('id', userId),
              supabase.from('merchants').upsert({
                'owner_name': _ownerNameController.text.trim(),
                'id': userId,
                'store_name': _storeNameController.text.trim(),
                'store_description': _descriptionController.text.trim(),
                'phone_number': _phoneController.text.trim(),
                'cr_number': _crNumberController.text.trim(),
                'store_url': _storeUrlController.text.trim(),
                'email_contact': _emailController.text.trim(),
              }),
              supabase.from('merchants').upsert({
                'id': userId,
                'store_name': _storeNameController.text.trim(),
                'store_description': _descriptionController.text.trim(),
                'phone_number': _phoneController.text.trim(),
                'cr_number': _crNumberController.text.trim(),
                'store_url': _storeUrlController.text.trim(),
              }),
            ]);
            setState(() => _isEditing = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("تم حفظ البيانات بنجاح ✅"),
                  backgroundColor: brandColor));
            }
          } catch (e) {
            debugPrint("Save Error: $e");
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isEditing ? brandColor : primaryBlue,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        _isEditing ? "حفظ التعديلات" : "تعديل الإعدادات",
        style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white),
      ),
    );
  }
}
