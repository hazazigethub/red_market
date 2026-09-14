import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _brandRed = Color(0xFFD32027);

/// يعرض شروط الإعلان في نافذة، ويُرجع true إن وافق التاجر
Future<bool?> showBannerTermsSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BannerTermsSheet(),
  );
}

class _BannerTermsSheet extends StatefulWidget {
  const _BannerTermsSheet();

  @override
  State<_BannerTermsSheet> createState() => _BannerTermsSheetState();
}

class _BannerTermsSheetState extends State<_BannerTermsSheet> {
  String _content = '';
  String _version = '';
  bool _loading = true;
  String? _error;

  static const _highlights = [
    'الإلغاء متاح خلال 24 ساعة من الحجز فقط',
    'العرض يبدأ من الأسبوع التالي لا الجاري',
    'لا ضمان لعدد الظهور أو النقرات',
    'أنت مسؤول قانونياً عن محتوى البنر',
    'الأسعار لا تشمل ضريبة القيمة المضافة 15%',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client
          .from('banner_terms')
          .select('version, content_ar')
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted) return;

      if (res == null) {
        setState(() {
          _error = 'لم تُنشر الشروط بعد';
          _loading = false;
        });
        return;
      }

      setState(() {
        _content = (res['content_ar'] ?? '').toString();
        _version = (res['version'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Terms load error: $e');
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل الشروط';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded,
                      color: _brandRed, size: 19),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('شروط وأحكام الإعلان',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (_version.isNotEmpty)
                    Text(_version,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                ],
              ),
            ),

            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: _brandRed)),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: 'Cairo', color: Colors.grey)),
                        )
                      : SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ===== الملخّص =====
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.orange
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('أهم ما يجب معرفته',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    ..._highlights.map((h) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 7),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ',
                                                  style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 12.5)),
                                              Expanded(
                                                child: Text(h,
                                                    style: const TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 12,
                                                        height: 1.8)),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ===== النص الكامل =====
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(
                                  _content,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      height: 2.0),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // ===== الأزرار =====
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xFFEDEFF3))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text('إغلاق',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading || _error != null
                            ? null
                            : () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: const Text('أوافق على الشروط',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
