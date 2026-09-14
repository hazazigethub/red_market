import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إدارة الحملات الموسمية
class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _campaigns = [];
  final Map<String, int> _productCounts = {};
  final Map<String, int> _merchantCounts = {};
  final Map<String, double> _revenue = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final camps = await supabase
          .from('seasonal_campaigns')
          .select()
          .order('starts_at', ascending: false);

      final stats = await supabase
          .from('campaign_product_stats')
          .select('campaign_id, current_status');

      final quotas = await supabase
          .from('campaign_quotas')
          .select('campaign_id, merchant_id, total_paid');

      _productCounts.clear();
      _merchantCounts.clear();
      _revenue.clear();

      for (final s in List<Map<String, dynamic>>.from(stats)) {
        if (s['current_status'] != 'active') continue;
        final cid = s['campaign_id'].toString();
        _productCounts[cid] = (_productCounts[cid] ?? 0) + 1;
      }

      for (final q in List<Map<String, dynamic>>.from(quotas)) {
        final cid = q['campaign_id'].toString();
        _merchantCounts[cid] = (_merchantCounts[cid] ?? 0) + 1;
        _revenue[cid] =
            (_revenue[cid] ?? 0) + ((q['total_paid'] as num?)?.toDouble() ?? 0);
      }

      if (!mounted) return;
      setState(() {
        _campaigns = List<Map<String, dynamic>>.from(camps);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Campaigns load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  String _fmt(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  /// حالة الحملة
  ({String label, Color color}) _statusOf(Map<String, dynamic> c) {
    final start = DateTime.tryParse((c['starts_at'] ?? '').toString());
    final end = DateTime.tryParse((c['ends_at'] ?? '').toString());
    final today = DateTime.now();

    if (end != null && end.isBefore(DateTime(today.year, today.month, today.day))) {
      return (label: 'انتهت', color: Colors.grey);
    }
    if (start != null &&
        start.isAfter(DateTime(today.year, today.month, today.day))) {
      return (label: 'قادمة', color: Colors.blue);
    }
    if (c['is_active'] == true) {
      return (label: 'نشطة الآن', color: Colors.green);
    }
    return (label: 'متوقفة', color: Colors.orange);
  }

  /// نافذة إنشاء أو تعديل حملة
  void _campaignDialog({Map<String, dynamic>? edit}) {
    final title = TextEditingController(text: (edit?['title'] ?? '').toString());
    final desc =
        TextEditingController(text: (edit?['description'] ?? '').toString());
    final banner =
        TextEditingController(text: (edit?['banner_image'] ?? '').toString());
    final fee = TextEditingController(
        text: '${(edit?['entry_fee'] as num?)?.toInt() ?? 5}');

    DateTime? start = DateTime.tryParse((edit?['starts_at'] ?? '').toString());
    DateTime? end = DateTime.tryParse((edit?['ends_at'] ?? '').toString());
    bool saving = false;

    // صورة البنر — مقاس 30:7
    Uint8List? imageBytes;
    String? imageName;
    String? imageError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.campaign_outlined,
                      color: brandRed, size: 17),
                ),
                const SizedBox(width: 11),
                Text(edit == null ? 'حملة جديدة' : 'تعديل الحملة',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: title,
                      style:
                          const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
                      decoration:
                          _dec('اسم الحملة', Icons.title_rounded),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: desc,
                      maxLines: 2,
                      style:
                          const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      decoration: _dec('وصف مختصر', Icons.notes_rounded),
                    ),
                    const SizedBox(height: 14),

                    // ===== التواريخ =====
                    Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            label: 'يبدأ',
                            value: start,
                            onPick: (d) => setModal(() => start = d),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dateField(
                            label: 'ينتهي',
                            value: end,
                            onPick: (d) => setModal(() => end = d),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: fee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style:
                          const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
                      decoration:
                          _dec('رسم العرض الواحد', Icons.payments_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ===== صورة البنر =====
                    Row(
                      children: [
                        const Icon(Icons.image_outlined,
                            size: 17, color: brandRed),
                        const SizedBox(width: 9),
                        const Text('صورة البنر',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('1500 × 350 · نسبة 30:7',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                color: Colors.grey.shade500)),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (imageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(imageBytes!,
                            height: 90, fit: BoxFit.cover),
                      )
                    else if (banner.text.trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          banner.text.trim(),
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                    if (imageBytes != null ||
                        banner.text.trim().isNotEmpty)
                      const SizedBox(height: 8),

                    InkWell(
                      onTap: saving
                          ? null
                          : () async {
                              try {
                                // ضغط تلقائي: عرض 1500 يكفي أكبر شاشة،
                                // وجودة 85 لا يُلحظ فرقها في بنر عريض
                                final picked = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1500,
                                    imageQuality: 85);
                                if (picked == null) return;

                                final bytes = await picked.readAsBytes();

                                final kb = bytes.lengthInBytes / 1024;
                                if (kb > 200) {
                                  setModal(() => imageError =
                                      'الحجم ${kb.toStringAsFixed(0)} ك.ب — '
                                      'والحد 200\n'
                                      'اضغط الصورة قبل الرفع');
                                  return;
                                }

                                final d =
                                    await decodeImageFromList(bytes);
                                final ratio = d.width / d.height;
                                if ((ratio - (30 / 7)).abs() > 0.15) {
                                  setModal(() => imageError =
                                      'النسبة غير مطابقة\n'
                                      'الصورة: ${d.width} × ${d.height}\n'
                                      'المطلوب نسبة 30:7');
                                  return;
                                }

                                setModal(() {
                                  imageBytes = bytes;
                                  imageName = picked.name;
                                  imageError = null;
                                });
                              } catch (e) {
                                debugPrint('Pick error: $e');
                                setModal(
                                    () => imageError = 'تعذر قراءة الصورة');
                              }
                            },
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: imageBytes != null
                              ? Colors.green.withValues(alpha: 0.05)
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: imageBytes != null
                                ? Colors.green.withValues(alpha: 0.35)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              imageBytes != null
                                  ? Icons.check_circle_rounded
                                  : Icons.upload_file_rounded,
                              size: 18,
                              color: imageBytes != null
                                  ? Colors.green
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                imageBytes != null
                                    ? 'صورة جديدة جاهزة'
                                    : (banner.text.trim().isEmpty
                                        ? 'اختر صورة البنر'
                                        : 'تغيير الصورة'),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  color: imageBytes != null
                                      ? Colors.green.shade800
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (imageError != null) ...[
                      const SizedBox(height: 8),
                      Text(imageError!,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              height: 1.8,
                              color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty) {
                          _snack('اكتب اسم الحملة', Colors.orange);
                          return;
                        }
                        if (start == null || end == null) {
                          _snack('حدّد تاريخي البداية والنهاية',
                              Colors.orange);
                          return;
                        }
                        if (end!.isBefore(start!)) {
                          _snack('تاريخ النهاية قبل البداية', Colors.orange);
                          return;
                        }

                        setModal(() => saving = true);

                        // رفع الصورة إن اختار جديدة
                        String? bannerUrl = banner.text.trim().isEmpty
                            ? null
                            : banner.text.trim();

                        if (imageBytes != null) {
                          try {
                            final ext =
                                (imageName ?? 'banner.jpg').split('.').last;
                            final path =
                                'campaign-${DateTime.now().millisecondsSinceEpoch}.$ext';

                            await supabase.storage
                                .from('campaigns')
                                .uploadBinary(
                                  path,
                                  imageBytes!,
                                  fileOptions:
                                      const FileOptions(upsert: true),
                                );

                            bannerUrl = supabase.storage
                                .from('campaigns')
                                .getPublicUrl(path);
                          } catch (e) {
                            debugPrint('Upload error: $e');
                            setModal(() => saving = false);
                            _snack('تعذر رفع الصورة', Colors.red);
                            return;
                          }
                        }

                        final data = {
                          'title': title.text.trim(),
                          'description': desc.text.trim().isEmpty
                              ? null
                              : desc.text.trim(),
                          'banner_image': bannerUrl,
                          'starts_at':
                              start!.toIso8601String().substring(0, 10),
                          'ends_at': end!.toIso8601String().substring(0, 10),
                          'entry_fee': int.tryParse(fee.text.trim()) ?? 5,
                        };

                        try {
                          if (edit == null) {
                            await supabase
                                .from('seasonal_campaigns')
                                .insert(data);
                          } else {
                            await supabase
                                .from('seasonal_campaigns')
                                .update(data)
                                .eq('id', edit['id']);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          _snack(
                              edit == null ? 'أُنشئت الحملة' : 'حُفظت الحملة',
                              Colors.green);
                        } catch (e) {
                          debugPrint('Save campaign error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر الحفظ', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري الحفظ...' : 'حفظ',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 400)),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                value == null
                    ? label
                    : '${value.day}/${value.month}/${value.year}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  color: value == null
                      ? Colors.grey.shade500
                      : const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: brandRed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  /// حذف حملة مع استرداد كامل
  Future<void> _deleteCampaign(Map<String, dynamic> c) async {
    final id = c['id'].toString();
    final merchants = _merchantCounts[id] ?? 0;
    final revenue = _revenue[id] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 19),
              SizedBox(width: 10),
              Text('حذف الحملة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ستُحذف حملة "${c['title']}" نهائياً بكل بياناتها.',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
                ),
                if (merchants > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.undo_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'سيُعاد ${revenue.toStringAsFixed(2)} ر.س '
                            'إلى $merchants تاجر، ويصلهم إشعار بذلك.',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                height: 1.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائي',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await supabase
          .rpc('delete_campaign', params: {'p_campaign_id': id});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        final n = (map['merchants'] as num?)?.toInt() ?? 0;
        _snack(
          n > 0
              ? 'حُذفت الحملة وأُعيد '
                  '${(map['refunded'] as num?)?.toStringAsFixed(2)} ر.س لـ$n تاجر'
              : 'حُذفت الحملة',
          Colors.orange,
        );
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الحذف', Colors.red);
      }
    } catch (e) {
      debugPrint('Delete campaign error: $e');
      _snack('تعذر تنفيذ الحذف', Colors.red);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> c, bool value) async {
    try {
      await supabase
          .from('seasonal_campaigns')
          .update({'is_active': value}).eq('id', c['id']);
      await _load();
    } catch (e) {
      debugPrint('Toggle error: $e');
      _snack('تعذر التغيير', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('الحملات الموسمية',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text('${_campaigns.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _campaignDialog(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('حملة جديدة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'الحملة تُفتح وتُغلق تلقائياً بتواريخها — والمفتاح للإيقاف الطارئ',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_campaigns.isEmpty)
                    _empty()
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        const gap = 12.0;
                        int cols = 3;
                        if (c.maxWidth < 620) {
                          cols = 1;
                        } else if (c.maxWidth < 1000) {
                          cols = 2;
                        }
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: _campaigns
                              .map((camp) =>
                                  SizedBox(width: w, child: _card(camp)))
                              .toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> c) {
    final id = c['id'].toString();
    final st = _statusOf(c);
    final products = _productCounts[id] ?? 0;
    final merchants = _merchantCounts[id] ?? 0;
    final revenue = _revenue[id] ?? 0;
    final desc = (c['description'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: st.label == 'نشطة الآن'
              ? Colors.green.withValues(alpha: 0.35)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (c['title'] ?? '').toString(),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt(c['starts_at'])} — ${_fmt(c['ends_at'])}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: st.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(st.label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: st.color)),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _campaignDialog(edit: c),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.edit_outlined,
                      size: 17, color: Colors.grey.shade600),
                ),
              ),
              InkWell(
                onTap: () => _deleteCampaign(c),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 17, color: Colors.red),
                ),
              ),
            ],
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.8,
                    color: Colors.grey.shade700)),
          ],

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              _stat(Icons.inventory_2_outlined, '$products عرض'),
              const SizedBox(width: 18),
              _stat(Icons.storefront_outlined, '$merchants تاجر'),
              const SizedBox(width: 18),
              _stat(Icons.payments_outlined,
                  '${(c['entry_fee'] as num?)?.toInt() ?? 5} ر.س للعرض'),
              const Spacer(),
              Text(
                '${revenue.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: c['is_active'] == true,
                  activeColor: Colors.green,
                  onChanged: (v) => _toggleActive(c, v),
                ),
              ),
              Text(
                c['is_active'] == true
                    ? 'ظاهرة للتجار والعملاء'
                    : 'مخفية',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined,
              size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا حملات بعد',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
