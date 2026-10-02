import 'package:flutter/material.dart';

import 'admin_contacts_screen.dart';
import 'admin_reports_screen.dart';

/// قسم التواصل والدعم
class AdminSupportHubScreen extends StatefulWidget {
  const AdminSupportHubScreen({super.key});

  @override
  State<AdminSupportHubScreen> createState() =>
      _AdminSupportHubScreenState();
}

class _AdminSupportHubScreenState extends State<AdminSupportHubScreen> {
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
            // ===== التبويبات =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _tabChip(0, 'رسائل التواصل',
                          Icons.mark_email_unread_outlined),
                      _tabChip(1, 'خدمة العملاء', Icons.support_agent),
                      _tabChip(2, 'دعم المتاجر',
                          Icons.contact_support_outlined),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  AdminContactsScreen(),
                  ReportsDetailsPage(
                    filterValue: 'user_support',
                    title: 'خدمة العملاء',
                    tableName: 'reports',
                    embedded: true,
                  ),
                  ReportsDetailsPage(
                    filterValue: 'merchant_support',
                    title: 'دعم المتاجر',
                    tableName: 'reports',
                    embedded: true,
                  ),
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
