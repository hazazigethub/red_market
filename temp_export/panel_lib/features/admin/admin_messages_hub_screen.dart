import 'package:flutter/material.dart';

import 'admin_notifications_screen.dart';
import 'admin_announcements_screen.dart';

/// قسم الرسائل — إشعارات التطبيق والإعلانات المنبثقة
class AdminMessagesHubScreen extends StatefulWidget {
  const AdminMessagesHubScreen({super.key});

  @override
  State<AdminMessagesHubScreen> createState() =>
      _AdminMessagesHubScreenState();
}

class _AdminMessagesHubScreenState extends State<AdminMessagesHubScreen> {
  static const Color brandRed = Color(0xFFD32027);

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            // ===== التبويبان =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    children: [
                      _tabChip(0, 'إشعارات التطبيق',
                          Icons.notifications_outlined),
                      const SizedBox(width: 10),
                      _tabChip(1, 'الإعلانات المنبثقة',
                          Icons.campaign_outlined),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  AdminNotificationsScreen(),
                  AdminAnnouncementsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(int index, String label, IconData icon) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: on ? brandRed : const Color(0xFFEDEFF3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17, color: on ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
