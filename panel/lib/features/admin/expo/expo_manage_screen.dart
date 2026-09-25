import 'package:flutter/material.dart';

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
  int _tab = 0;
  int _version = 0; // يعيد بناء التبويب بعد أي تعديل على المعرض

  static const _tabs = <(String, IconData)>[
    ('نظرة عامة', Icons.dashboard_outlined),
    ('طلبات العارضين', Icons.how_to_reg_outlined),
    ('القاعات والأجنحة', Icons.grid_view_rounded),
    ('الجلسات', Icons.mic_none_rounded),
    ('المتحدثون', Icons.record_voice_over_outlined),
    ('الرعاة', Icons.workspace_premium_outlined),
    ('غرفة التحكم', Icons.podcasts_rounded),
  ];

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
      if (mounted) {
        setState(() {
          _e = row;
          _version++;
        });
      }
    } catch (e) {
      if (mounted) expoToast(context, expoError(e), error: true);
    }
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => ExpoExhibitionFormPage(exhibition: _e));
    if (saved == true) _reload();
  }

  Widget _body(Map<String, dynamic> e) {
    final id = widget.exhibitionId;
    final key = ValueKey('$_tab-$_version');
    return switch (_tab) {
      0 => OverviewTab(key: key, exhibition: e, onChanged: _reload, onEdit: _edit),
      1 => ApplicationsTab(key: key, exhibitionId: id),
      2 => HallsTab(key: key, exhibitionId: id),
      3 => SessionsTab(key: key, exhibitionId: id),
      4 => SpeakersTab(key: key, exhibitionId: id),
      5 => SponsorsTab(key: key, exhibitionId: id),
      _ => ControlTab(key: key, exhibition: e),
    };
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final status = '${e?['status'] ?? ''}';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: e == null
              ? expoLoader()
              : ExpoPage(
                  onRefresh: _reload,
                  children: [
                    // ===== الرأس =====
                    Row(children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 15),
                        label: const Text('رجوع',
                            style: TextStyle(
                                fontFamily: kExpoFont,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: kBrand),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('${e['title']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: kExpoFont,
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      expoChip(kExhibitionStatus[status] ?? status,
                          kExhibitionStatusColor[status] ?? Colors.grey),
                      const Spacer(),
                      expoIconAction(Icons.open_in_new_rounded,
                          () => expoOpen('/e/${e['slug']}'),
                          tooltip: 'عرض كزائر'),
                      expoButton('تعديل المعرض', _edit, icon: Icons.edit_outlined),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 16),
                      child: expoSub(
                          '${e['organizers']?['name'] ?? ''} · ${expoFmtDateTime(e['starts_at'])} — ${expoFmtDateTime(e['ends_at'])}'),
                    ),
                    ExpoTabs(
                        tabs: _tabs,
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i)),
                    const SizedBox(height: 18),
                    _body(e),
                  ],
                ),
        ),
      ),
    );
  }
}
