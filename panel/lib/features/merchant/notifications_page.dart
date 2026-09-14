import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  String get _uid => supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// يطلق الإشعارات المجدولة ثم يجلب ما يخص التاجر
  Future<List<Map<String, dynamic>>> _load() async {
    // الجلسة قد لا تكون جاهزة عند أول بناء
    var uid = _uid;
    if (uid.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 400));
      uid = _uid;
      if (uid.isEmpty) return [];
    }

    try {
      await supabase.rpc('release_due_notifications');
    } catch (e) {
      debugPrint('Release error: $e');
    }

    // الدالة تستبعد ما سبق تسجيل المستخدم وتحسب المقروء
    final data = await supabase.rpc('get_my_notifications',
        params: {'p_limit': 100});

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> _refresh() async {
    try {
      final list = await _load();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load notifications error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    if (_uid.isEmpty) return;

    setState(() {
      final i = _items.indexWhere((n) => n['id']?.toString() == id);
      if (i != -1) _items[i] = {..._items[i], 'is_read': true};
    });

    try {
      await supabase.from('notification_reads').upsert({
        'user_id': _uid,
        'notification_id': id,
      }, onConflict: 'user_id,notification_id');
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      setState(() => _items.removeWhere((n) => n['id']?.toString() == id));
      await supabase.from('notifications_log').delete().eq('id', id);
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  IconData _iconFor(String? iconType, String title) {
    switch (iconType) {
      case 'promo':
        return Icons.campaign_outlined;
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'newsletter':
        return Icons.mail_outline_rounded;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '';
    final local = d.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return DateFormat('MM-dd').format(local);
  }

  void _showDialog(Map<String, dynamic> item) {
    final nlId = item['newsletter_id'];
    final pId = item['product_id'];
    final rId = item['reel_id'];

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Text(
                (item['body'] ?? '').toString(),
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    height: 1.9,
                    color: Color(0xFF1F2937)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إغلاق",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            if (nlId != null)
              _dialogAction(ctx, Icons.open_in_new_rounded, "تصفّح النشرة",
                  'https://redmarket.sa/newsletter/$nlId')
            else if (pId != null)
              _dialogAction(ctx, Icons.shopping_bag_rounded, "فتح العرض",
                  'https://redmarket.sa/product/$pId')
            else if (rId != null)
              _dialogAction(ctx, Icons.play_circle_fill_rounded,
                  "مشاهدة الريلز", 'https://redmarket.sa/reels'),
          ],
        ),
      ),
    );
  }

  Widget _dialogAction(
      BuildContext ctx, IconData icon, String label, String url) {
    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.pop(ctx);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      icon: Icon(icon, size: 17),
      label: Text(label,
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: brandRed,
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_uid.isEmpty && !_loading) {
      return const Center(
        child: Text("سجّل دخول أولاً",
            style: TextStyle(fontFamily: 'Cairo')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: brandRed,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: brandRed))
            : _items.isEmpty
                ? _emptyState(isDark)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            const gap = 14.0;
                            // خمس بطاقات في الصف، وتقل مع ضيق الشاشة
                            final cols = (c.maxWidth / 280).floor().clamp(1, 5);
                            final w = (c.maxWidth - gap * (cols - 1)) / cols;

                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: _items
                                  .map((n) => SizedBox(
                                        width: w,
                                        child: _item(
                                            n,
                                            n['is_read'] ?? false,
                                            isDark),
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _item(Map<String, dynamic> n, bool isRead, bool isDark) {
    return InkWell(
      onTap: () {
        _markAsRead(n['id'].toString());
        _showDialog(n);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E1E)
              : (isRead ? Colors.white : const Color(0xFFFDF3F3)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isRead
                  ? const Color(0xFFEDEFF3)
                  : brandRed.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: isRead ? 0.06 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(n['icon_type']?.toString(),
                        (n['title'] ?? '').toString()),
                    color: isRead ? Colors.grey : brandRed,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (n['title'] ?? 'إشعار').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.5,
                      fontWeight:
                          isRead ? FontWeight.w500 : FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _delete(n['id'].toString()),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 15, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!isRead) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: brandRed, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatTime(n['scheduled_at'] ?? n['created_at']),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.notifications_off_outlined,
            size: 60, color: isDark ? Colors.white12 : Colors.grey.shade300),
        const SizedBox(height: 14),
        const Center(
          child: Text("لا توجد إشعارات حالياً",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        ),
      ],
    );
  }
}
