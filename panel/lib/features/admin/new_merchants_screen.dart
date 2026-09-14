import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_merchants_screen.dart';

/// التجار الجدد — بانتظار مراجعة الوثائق
class NewMerchantsScreen extends StatefulWidget {
  const NewMerchantsScreen({super.key});

  @override
  State<NewMerchantsScreen> createState() => _NewMerchantsScreenState();
}

class _NewMerchantsScreenState extends State<NewMerchantsScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  bool _onlyUnverified = true;
  String _query = '';

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from('merchants')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      if (!mounted) return;
      setState(() {
        _all = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      debugPrint('New merchants error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  List<Map<String, dynamic>> get _visible {
    var list = _all;

    if (_onlyUnverified) {
      list = list.where((m) => (m['is_verified'] ?? false) != true).toList();
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((m) {
        final name = (m['store_name'] ?? '').toString().toLowerCase();
        final cr = (m['cr_number'] ?? '').toString();
        final owner = (m['owner_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || cr.contains(q) || owner.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final unverified =
        _all.where((m) => (m['is_verified'] ?? false) != true).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFF1F2937),
          title: const Text('التجار الجدد',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded, size: 21),
              onPressed: _load,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: brandRed,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== الفلتر والبحث =====
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 620;

                        final chip = _filterChip(unverified);
                        final search = _searchField();

                        if (!wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              chip,
                              const SizedBox(height: 12),
                              search,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            chip,
                            const SizedBox(width: 14),
                            Expanded(child: search),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: brandRed)),
                      )
                    else if (_visible.isEmpty)
                      _empty()
                    else
                      LayoutBuilder(
                        builder: (context, c) {
                          const gap = 12.0;
                          int cols = 4;
                          if (c.maxWidth < 560) {
                            cols = 1;
                          } else if (c.maxWidth < 850) {
                            cols = 2;
                          } else if (c.maxWidth < 1200) {
                            cols = 3;
                          }
                          final w = (c.maxWidth - gap * (cols - 1)) / cols;

                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: _visible
                                .map((m) =>
                                    SizedBox(width: w, child: _card(m)))
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
      ),
    );
  }

  Widget _filterChip(int count) {
    final on = _onlyUnverified;
    return GestureDetector(
      onTap: () => setState(() => _onlyUnverified = !on),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: on ? Colors.orange.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: on ? Colors.orange : const Color(0xFFEDEFF3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_off_outlined,
              size: 17,
              color: on ? Colors.orange.shade800 : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              on ? 'بانتظار الفحص ($count)' : 'كل التجار (${_all.length})',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color:
                    on ? Colors.orange.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'ابحث باسم المتجر أو رقم السجل',
          hintStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search_rounded,
              size: 19, color: Colors.grey.shade500),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 17, color: Colors.grey.shade500),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFEDEFF3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: brandRed, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final verified = (m['is_verified'] ?? false) == true;
    final banned = (m['is_banned'] ?? false) == true;

    final (IconData icon, Color color) = banned
        ? (Icons.block_rounded, Colors.red)
        : verified
            ? (Icons.verified_outlined, Colors.green)
            : (Icons.store_outlined, Colors.orange);

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MerchantControlScreen(merchant: m),
        ));
        _load();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !verified && !banned
                ? Colors.orange.withValues(alpha: 0.35)
                : const Color(0xFFEDEFF3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    (m['store_name'] ?? 'متجر بلا اسم').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _line(Icons.badge_outlined,
                (m['cr_number'] ?? 'بلا سجل').toString()),
            const SizedBox(height: 7),
            _line(Icons.person_outline_rounded,
                (m['owner_name'] ?? '—').toString()),
            const SizedBox(height: 7),
            _line(Icons.calendar_today_rounded, _fmtDate(m['created_at'])),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFEDEFF3), height: 1),
            const SizedBox(height: 11),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    banned
                        ? 'محظور'
                        : verified
                            ? 'تم الفحص'
                            : 'بانتظار الفحص',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                const Spacer(),
                Text('مراجعة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                Icon(Icons.chevron_left_rounded,
                    size: 17, color: Colors.grey.shade500),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.store_outlined, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            _onlyUnverified ? 'لا تجار بانتظار الفحص' : 'لا نتائج',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
