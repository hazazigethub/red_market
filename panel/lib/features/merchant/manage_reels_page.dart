import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'package:video_compress/video_compress.dart';
import 'review_reels_page.dart';

class ManageReelsPage extends StatefulWidget {
  final String? merchantId;
  const ManageReelsPage({super.key, this.merchantId});

  @override
  State<ManageReelsPage> createState() => _ManageReelsPageState();
}

class _ManageReelsPageState extends State<ManageReelsPage> {
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;
  bool _isUploading = false;
  int _reelsLimit = 0;
  int _currentReelsCount = 0;

  final List<String> _deletedIds = [];

  static const Color brandRed = Color(0xFFD32027);

  String get _merchantId => supabase.auth.currentUser?.id ?? "";

  /// أسماء عروض التاجر: المعرّف -> الاسم
  final Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _reelsFuture = _loadReels();
    _fetchReelsLimit();
    _loadProductNames();
  }

  /// يجلب أسماء العروض لعرضها على البطاقات وفي نافذة التعديل
  Future<void> _loadProductNames() async {
    try {
      final res = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', _merchantId)
          .order('name');

      final map = <String, String>{};
      for (final p in List<Map<String, dynamic>>.from(res as List)) {
        final id = p['id']?.toString();
        final name = p['name']?.toString();
        if (id != null && name != null) map[id] = name;
      }

      if (mounted) setState(() => _productNames.addAll(map));
    } catch (e) {
      debugPrint('Load product names error: $e');
    }
  }

  late Future<List<Map<String, dynamic>>> _reelsFuture;

  Future<List<Map<String, dynamic>>> _loadReels() async {
    final v = await supabase
        .from('reels')
        .select()
        .eq('merchant_id', _merchantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(v);
  }

  void _refreshReels() {
    if (mounted) setState(() { _reelsFuture = _loadReels(); });
  }

  Future<void> _fetchReelsLimit() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // الحد محفوظ في profiles عند إسناد الباقة
      final profile = await supabase
          .from('profiles')
          .select('max_reels')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return;

      final limit = (profile['max_reels'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _reelsLimit = limit;
        });
      }
    } catch (e) {
      debugPrint("خطأ في جلب حد الريلز: $e");
    }
  }

  // ✅ مضاف: جلب عروض التاجر
  Future<List<Map<String, dynamic>>> _fetchMerchantProducts() async {
    try {
      final res = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', _merchantId)
          .eq('is_available', true)
          .order('name');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  // ✅ مضاف: productId parameter
  Future<void> _handleUpload(String title, String desc, XFile videoFile,
      {String? productId}) async {
    if (_merchantId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final int fileSize = await videoFile.length();
    if (fileSize > 100 * 1024 * 1024) {
      messenger.showSnackBar(const SnackBar(
          content: Text("حجم الملف كبير جداً (الحد 100 ميجابايت)")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // الويب: لا يتوفر ضغط أو فحص مدة قبل الرفع — يُرفع الملف كما هو
      if (_currentReelsCount >= _reelsLimit) {
        if (mounted) {
          setState(() => _isUploading = false);
          _showErrorDialog(
              "وصلت للحد الأقصى", "باقتك تسمح بـ $_reelsLimit ريلز فقط.");
        }
        return;
      }

      final videoBytes = await videoFile.readAsBytes();
      final mime = videoFile.mimeType ?? 'video/mp4';
      final fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = 'uploads/$_merchantId/$fileName';

      await supabase.storage.from('reels').uploadBinary(
            path,
            videoBytes,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );

      final String videoUrl = supabase.storage.from('reels').getPublicUrl(path);

      String merchantName = 'متجر';
      String merchantImg = '';
      try {
        final profile = await supabase
            .from('merchants')
            .select()
            .eq('id', _merchantId)
            .maybeSingle();
        if (profile != null) {
          merchantName = profile['store_name'] ?? 'متجر';
          merchantImg = profile['logo_url'] ?? '';
        }
      } catch (_) {}

      // ✅ مضاف: product_id في الـ insert
      await supabase.from('reels').insert({
        'merchant_id': _merchantId,
        'title': title,
        'description': desc,
        'video_url': videoUrl,
        'thumbnail_url':
            'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=500',
        'created_at': DateTime.now().toIso8601String(),
        'likes_count': 0,
        'comments_count': 0,
        'is_active': true,
        if (productId != null) 'product_id': productId, // ✅ مضاف
      });

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text("تم نشر الرييل بنجاح 🚀",
                style: TextStyle(fontFamily: 'Cairo'))),
      );
      navigator.pop();
      _refreshReels();
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text("حدث خطأ أثناء الرفع: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              const Icon(Icons.timer_off_outlined, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
        ),
        content: Text(content,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("حسناً فهمت",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: brandRed)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _deleteReel(String id) async {
    setState(() => _deletedIds.add(id));
    try {
      await supabase.from('reels').delete().eq('id', id);
      _refreshReels();
    } catch (e) {
      setState(() => _deletedIds.remove(id));
      debugPrint("Delete Error: $e");
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isUploading
              ? null
              : () {
                  if (_currentReelsCount >= _reelsLimit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "وصلت للحد الأقصى ($_reelsLimit ريلز). رقّ باقتك لإضافة المزيد.",
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  _showReelForm();
                },
          backgroundColor: brandRed,
          icon: const Icon(Icons.video_call_rounded, color: Colors.white),
          label: const Text("إضافة رييل",
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: brandRed));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _currentReelsCount != 0) {
                  setState(() => _currentReelsCount = 0);
                }
              });
              return _buildEmptyState();
            }

            final activeCount = snapshot.data!
                .where((r) => !_deletedIds.contains(r['id'].toString()))
                .length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _currentReelsCount != activeCount) {
                setState(() => _currentReelsCount = activeCount);
              }
            });

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentReelsCount >= _reelsLimit
                        ? Colors.red.withValues(alpha: 0.08)
                        : brandRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentReelsCount >= _reelsLimit
                          ? Colors.red.withValues(alpha: 0.3)
                          : brandRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        color: _currentReelsCount >= _reelsLimit
                            ? Colors.red
                            : brandRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "الريلز: $_currentReelsCount / $_reelsLimit",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _currentReelsCount >= _reelsLimit
                              ? Colors.red
                              : brandRed,
                        ),
                      ),
                      if (_currentReelsCount >= _reelsLimit) ...[
                        const Spacer(),
                        const Text(
                          "وصلت للحد الأقصى",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 9 / 16,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final reel = ReelModel.fromMap(snapshot.data![index]);
                      if (_deletedIds.contains(reel.id)) {
                        return const SizedBox.shrink();
                      }
                      return _buildReelCard(reel, isDark);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReelCard(ReelModel reel, bool isDark) {
    final linked = reel.productId != null && reel.productId!.isNotEmpty;
    final productName = linked ? _productNames[reel.productId!] : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReviewReelsPage(reel: reel)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              reel.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.play_circle,
                    size: 40, color: Colors.white70),
              ),
            ),

            // تدرّج أسفل البطاقة لإبراز النص
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reel.title ?? "بدون عنوان",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    if (linked) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_rounded,
                                size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                productName ?? "مرتبط بعرض",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // زر التعديل
            Positioned(
              top: 6,
              left: 6,
              child: GestureDetector(
                onTap: () => _showReelOptions(reel),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 15, color: brandRed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// خيارات تعديل أو حذف الريلز
  void _showReelOptions(ReelModel reel) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            reel.title ?? "الريلز",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: brandRed),
                title: const Text("تعديل التفاصيل",
                    style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditReelDialog(reel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("حذف الريلز",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(reel.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// تعديل عنوان ووصف الريلز والعرض المرتبط
  void _showEditReelDialog(ReelModel reel) {
    final titleCtrl = TextEditingController(text: reel.title ?? '');
    final descCtrl = TextEditingController(text: reel.description ?? '');
    String? productId = reel.productId;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text("تعديل تفاصيل الريلز",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(
                      labelText: "العنوان",
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontFamily: 'Cairo'),
                    decoration: const InputDecoration(
                      labelText: "الوصف",
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: productId,
                    isExpanded: true,
                    style: const TextStyle(
                        fontFamily: 'Cairo', color: Colors.black87),
                    decoration: const InputDecoration(
                      labelText: "العرض المرتبط",
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text("بدون عرض",
                            style: TextStyle(fontFamily: 'Cairo')),
                      ),
                      ..._productNames.entries.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.key,
                          child: Text(e.value,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => productId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text("إلغاء",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandRed),
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await supabase.from('reels').update({
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'product_id': productId,
                          }).eq('id', reel.id);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) setState(() {});
                        } catch (e) {
                          debugPrint('Update reel error: $e');
                          setDialogState(() => saving = false);
                        }
                      },
                child: Text(saving ? "جاري الحفظ..." : "حفظ",
                    style: const TextStyle(
                        fontFamily: 'Cairo', color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReelForm() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    XFile? video;
    String? selectedProductId; // ✅ مضاف

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isUploading)
                const Column(
                  children: [
                    LinearProgressIndicator(color: brandRed),
                    SizedBox(height: 8),
                    Text("جاري معالجة الفيديو... (يرجى الانتظار)",
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  ],
                ),
              const SizedBox(height: 15),
              _buildTextField(titleController, "عنوان المقطع", false),
              const SizedBox(height: 10),
              _buildTextField(descController, "وصف قصير", false, maxLines: 2),
              const SizedBox(height: 10),

              // ✅ مضاف: Dropdown لاختيار العرض
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchMerchantProducts(),
                builder: (context, snapshot) {
                  final products = snapshot.data ?? [];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border:
                            Border.all(color: Theme.of(context).dividerColor)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: selectedProductId,
                        hint: const Text("ربط بعرض (اختياري)",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Colors.grey)),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("بدون ربط بعرض",
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 13)),
                          ),
                          ...products.map((p) => DropdownMenuItem<String?>(
                                value: p['id'].toString(),
                                child: Text(p['name'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 13)),
                              )),
                        ],
                        onChanged: (val) =>
                            setModalState(() => selectedProductId = val),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),

              InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  final picked =
                      await _picker.pickVideo(source: ImageSource.gallery);
                  if (picked != null) setModalState(() => video = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: video == null
                              ? Colors.grey.shade300
                              : Colors.green),
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      Icon(
                          video == null
                              ? Icons.video_library_outlined
                              : Icons.check_circle,
                          color: video == null ? Colors.grey : Colors.green,
                          size: 30),
                      const SizedBox(height: 5),
                      Text(
                          video == null
                              ? "اختر فيديو (أقل من 20 ثانية)"
                              : "تم اختيار الفيديو",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color:
                                  video == null ? Colors.grey : Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading
                      ? null
                      : () async {
                          if (video != null &&
                              titleController.text.isNotEmpty) {
                            await _handleUpload(
                              titleController.text,
                              descController.text,
                              video!,
                              productId: selectedProductId, // ✅ مضاف
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "يرجى ملء البيانات واختيار فيديو")));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: brandRed,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: Text(
                      _isUploading ? "جاري الرفع..." : "نشر الرييل الآن",
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("حذف الريلز",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: const Text("هل أنت متأكد من حذف هذا المقطع نهائياً؟",
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("تراجع",
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  _deleteReel(id);
                  Navigator.pop(context);
                },
                child: const Text("حذف",
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, bool isDark,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.video_library_outlined,
            size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 15),
        const Text("لا توجد مقاطع رييل منشورة حالياً",
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        const Text("(اضغط على الزر بالأسفل لإضافة أول مقطع)",
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
      ],
    ));
  }
}
