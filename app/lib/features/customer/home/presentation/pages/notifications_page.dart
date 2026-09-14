import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// يطلق الإشعارات المجدولة ثم يجلب ما يخص المستخدم
  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // إطلاق الإشعارات المجدولة التي حان موعدها
    try {
      await supabase.rpc('release_due_notifications');
    } catch (e) {
      debugPrint('Release notifications error: $e');
    }

    // الدالة تستبعد ما سبق تسجيل المستخدم وتحسب المقروء
    final data =
        await supabase.rpc('get_my_notifications', params: {'p_limit': 100});

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> _refresh() async {
    try {
      final list = await _loadNotifications();
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // تحديث فوري في الواجهة
    setState(() {
      final i = _items.indexWhere((n) => n['id']?.toString() == id);
      if (i != -1) _items[i] = {..._items[i], 'is_read': true};
    });

    try {
      await supabase.from('notification_reads').upsert({
        'user_id': userId,
        'notification_id': id,
      }, onConflict: 'user_id,notification_id');
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      setState(() => _items.removeWhere((n) => n['id']?.toString() == id));
      await supabase.from('notifications_log').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  void _showNotificationDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFD32027)),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['title'] ?? 'تنبيه',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child:
                      const Icon(Icons.close, color: Colors.white70, size: 22),
                ),
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              item['body'] ?? '',
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            if (item['newsletter_id'] != null)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(
                      'https://redmarket.sa/newsletter/${item['newsletter_id']}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text("تصفّح النشرة",
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32027),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )
            else if (item['product_id'] != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/product-details/${item['product_id']}');
                },
                icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                label: const Text("فتح العرض",
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32027),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )
            else if (item['reel_id'] != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/reels');
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                label: const Text("مشاهدة الريلز",
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32027),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
      }
      return "${date.day}/${date.month}";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "التنبيهات",
            style: TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFFD32027),
          child: Builder(
            builder: (context) {
              if (_loading) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD32027)));
              }

              final notifications = _items;

              if (notifications.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                itemCount: notifications.length,
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final bool isRead = notif['is_read'] ?? false;

                  return Dismissible(
                    key: Key(notif['id'].toString()),
                    direction: DismissDirection.startToEnd,
                    onDismissed: (direction) =>
                        _deleteNotification(notif['id'].toString()),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.delete_sweep,
                          color: Colors.white, size: 28),
                    ),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        _markAsRead(notif['id'].toString());
                        _showNotificationDialog(notif);
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isRead
                            ? null
                            : const Color(0xFFD32027).withValues(alpha: 0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(
                            color: Color(0xFFD32027),
                            width: 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isRead
                                      ? Colors.grey.shade100
                                      : const Color(0xFFD32027)
                                          .withValues(alpha: 0.1),
                                  child: Icon(
                                    isRead
                                        ? Icons.notifications_none_rounded
                                        : Icons.notifications_active_rounded,
                                    color: isRead
                                        ? Colors.grey
                                        : const Color(0xFFD32027),
                                    size: 22,
                                  ),
                                ),
                                if (!isRead)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD32027),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              notif['title'] ?? 'تنبيه جديد',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight:
                                    isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                notif['body'] ?? '',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: isRead ? Colors.grey : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Text(
                              _formatDate(notif['created_at'].toString()),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.notifications_off_outlined,
            size: 70, color: Colors.grey.shade200),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            "صندوق التنبيهات فارغ",
            style: TextStyle(
                fontFamily: 'Cairo', color: Colors.grey, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
