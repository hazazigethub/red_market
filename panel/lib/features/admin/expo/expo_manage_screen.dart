import 'package:flutter/material.dart';
import 'package:red_market_core/red_market_core.dart';

import 'expo_common.dart';
import 'expo_exhibition_form.dart';
import 'tabs/overview_tab.dart';
import 'tabs/applications_tab.dart';
import 'tabs/halls_tab.dart';
import 'tabs/sessions_tab.dart';
import 'tabs/speakers_tab.dart';
import 'tabs/sponsors_tab.dart';
import 'tabs/control_tab.dart';

/// إدارة معرض واحد بالكامل من لوحة الأدمن
class ExpoManageScreen extends StatefulWidget {
  final String exhibitionId;
  const ExpoManageScreen({super.key, required this.exhibitionId});

  @override
  State<ExpoManageScreen> createState() => _ExpoManageScreenState();
}

class _ExpoManageScreenState extends State<ExpoManageScreen> {
  Map<String, dynamic>? _e;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final row = await expoDb
          .from('exhibitions')
          .select('*, organizers(name)')
          .eq('id', widget.exhibitionId)
          .single();
      if (mounted) setState(() => _e = row);
    } catch (e) {
      if (mounted) expoToast(context, expoError(e), error: true);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ExpoExhibitionFormPage(exhibition: _e)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 7,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
            title: Text(e == null ? '…' : '${e['title']}',
                style: const TextStyle(
                    fontFamily: kExpoFont, fontWeight: FontWeight.bold)),
            actions: e == null
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: expoChip(
                          kExhibitionStatus['${e['status']}'] ?? '${e['status']}',
                          kExhibitionStatusColor['${e['status']}'] ?? Colors.grey),
                    ),
                    IconButton(
                        tooltip: 'تعديل المعرض',
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        tooltip: 'عرض كزائر',
                        onPressed: () => expoOpen('/e/${e['slug']}'),
                        icon: const Icon(Icons.open_in_new)),
                    const SizedBox(width: 8),
                  ],
            bottom: TabBar(
              isScrollable: true,
              labelColor: AppColors.brand,
              indicatorColor: AppColors.brand,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                  fontFamily: kExpoFont, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontFamily: kExpoFont),
              tabs: const [
                Tab(text: 'نظرة عامة'),
                Tab(text: 'طلبات العارضين'),
                Tab(text: 'القاعات والأجنحة'),
                Tab(text: 'الجلسات'),
                Tab(text: 'المتحدثون'),
                Tab(text: 'الرعاة'),
                Tab(text: 'غرفة التحكم'),
              ],
            ),
          ),
          body: e == null
              ? expoLoader()
              : TabBarView(
                  children: [
                    OverviewTab(exhibition: e, onChanged: _reload, onEdit: _edit),
                    ApplicationsTab(exhibitionId: widget.exhibitionId),
                    HallsTab(exhibitionId: widget.exhibitionId),
                    SessionsTab(exhibitionId: widget.exhibitionId),
                    SpeakersTab(exhibitionId: widget.exhibitionId),
                    SponsorsTab(exhibitionId: widget.exhibitionId),
                    ControlTab(exhibition: e),
                  ],
                ),
        ),
      ),
    );
  }
}
