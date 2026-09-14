import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// شروط وأحكام التاجر — تُقرأ من قاعدة البيانات
class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  String? _content;
  int? _version;
  DateTime? _updatedAt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final row = await supabase
          .from('terms_content')
          .select('content, version, updated_at')
          .eq('type', 'merchant')
          .maybeSingle();

      if (!mounted) return;

      if (row == null) {
        setState(() {
          _error = 'لم تُنشر الشروط بعد';
          _loading = false;
        });
        return;
      }

      setState(() {
        _content = (row['content'] ?? '').toString();
        _version = (row['version'] as num?)?.toInt();
        _updatedAt = DateTime.tryParse((row['updated_at'] ?? '').toString());
        _loading = false;
      });
    } catch (e) {
      debugPrint('Terms load error: $e');
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل الشروط، حاول مجدداً';
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text('الشروط والأحكام',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : _error != null
                ? _errorState()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: brandRed,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              if (_version != null || _updatedAt != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: brandRed.withValues(alpha: 0.05),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded,
                                          size: 16, color: brandRed),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (_version != null)
                                              'الإصدار $_version',
                                            if (_updatedAt != null)
                                              'آخر تحديث ${_fmt(_updatedAt)}',
                                          ].join(' · '),
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11.5,
                                              color: Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFEDEFF3)),
                                ),
                                child: SelectableText(
                                  _content ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13.5,
                                    height: 2.0,
                                    color: Color(0xFF2D3436),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
          Icon(Icons.description_outlined,
              size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(_error ?? '',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _load,
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
