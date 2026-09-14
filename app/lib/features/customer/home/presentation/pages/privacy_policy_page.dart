import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// سياسة الخصوصية للعميل — تُقرأ من قاعدة البيانات
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  static const Color brandRed = Color(0xFFD32027);

  String _content = '';
  int? _version;
  DateTime? _updatedAt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await Supabase.instance.client
          .from('terms_content')
          .select('content, version, updated_at')
          .eq('type', 'privacy_customer')
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = 'لم تُنشر السياسة بعد';
          _loading = false;
        });
        return;
      }

      setState(() {
        _content = (data['content'] ?? '').toString();
        _version = (data['version'] as num?)?.toInt();
        _updatedAt = DateTime.tryParse((data['updated_at'] ?? '').toString());
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching privacy: $e');
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل السياسة، حاول مجدداً';
          _loading = false;
        });
      }
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return "${d.year}/${d.month}/${d.day}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "سياسة الخصوصية",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : _error != null
                ? _errorState()
                : RefreshIndicator(
                    onRefresh: _fetch,
                    color: brandRed,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: brandRed.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: brandRed.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_outlined,
                                      color: brandRed, size: 22),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "خصوصيتك تهمّنا",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: brandRed,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "كيف نجمع بياناتك ونستخدمها ونحميها",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11.5,
                                          height: 1.7,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_version != null || _updatedAt != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 7),
                                Text(
                                  [
                                    if (_version != null) 'الإصدار $_version',
                                    if (_updatedAt != null)
                                      'آخر تحديث ${_fmt(_updatedAt)}',
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFEDEFF3)),
                            ),
                            child: SelectableText(
                              _content,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                height: 2.0,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF2D3436),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(_error ?? '',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontFamily: 'Cairo')),
            style: OutlinedButton.styleFrom(
              foregroundColor: brandRed,
              side: const BorderSide(color: brandRed),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
