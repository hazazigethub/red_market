import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  late TabController _tabController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSending = false;
  String _targetType = 'all'; // all, specific, segment
  String? _selectedSegment;
  Map<String, dynamic>? _selectedTarget;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _isScheduled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- دالة الإرسال أو الجدولة (بدون أي تغيير) ---
  Future<void> _handleSendOrSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetType == 'specific' && _selectedTarget == null) {
      _showSnackBar("يرجى البحث واختيار (متجر/عميل) محدد", Colors.orange);
      return;
    }
    if (_targetType == 'segment' && _selectedSegment == null) {
      _showSnackBar("يرجى اختيار القسم المستهدف", Colors.orange);
      return;
    }

    setState(() => _isSending = true);

    DateTime? finalSchedule;
    if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
      finalSchedule = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
    }

    try {
      await supabase.from('notifications_log').insert({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'target_type': _targetType,
        'target_id': _selectedTarget?['id'],
        'segment_filter': _selectedSegment,
        'scheduled_at': finalSchedule?.toIso8601String(),
        'status': finalSchedule == null ? 'sent' : 'scheduled',
      });

      _showSnackBar(
          finalSchedule == null
              ? "تم إرسال الإشعار بنجاح"
              : "تمت جدولة الإشعار بنجاح",
          Colors.green);
      _resetForm();
    } catch (e) {
      _showSnackBar("خطأ في العملية: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      _showSnackBar("يرجى كتابة العنوان والمحتوى لحفظهما كقالب", Colors.orange);
      return;
    }
    try {
      await supabase.from('notification_templates').insert({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
      });
      _showSnackBar("تم حفظ القالب بنجاح", Colors.blue);
    } catch (e) {
      _showSnackBar("فشل حفظ القالب", Colors.red);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _bodyController.clear();
    _searchController.clear();
    setState(() {
      _selectedTarget = null;
      _selectedSegment = null;
      _isScheduled = false;
      _scheduledDate = null;
      _scheduledTime = null;
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  /// يُنشأ مرة واحدة — وإلا أُعيد الاشتراك مع كل بناء
  late final Stream<List<Map<String, dynamic>>> _logsStream = supabase
      .from('notifications_log')
      .stream(primaryKey: ['id']).order('created_at', ascending: false);

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFD32027);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
          children: [
            // ===== التبويبان =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    children: [
                      _navChip(0, 'إرسال جديد', Icons.send_rounded,
                          brandRed),
                      const SizedBox(width: 10),
                      _navChip(1, 'السجل والجدولة',
                          Icons.history_rounded, brandRed),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildCreateNotificationTab(brandRed),
                      _buildLogsTab(brandRed),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navChip(int index, String label, IconData icon, Color brandRed) {
    final on = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
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

  Widget _buildCreateNotificationTab(Color brandRed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateSelector(brandRed),
            const SizedBox(height: 20),
            _buildTargetSelector(brandRed),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFEDEFF3))),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                      decoration: _buildInputDecoration(
                          "عنوان الإشعار (مثال: عرض جديد!)", Icons.title),
                      validator: (v) => v!.isEmpty ? "العنوان مطلوب" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _bodyController,
                      maxLines: 4,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      decoration: _buildInputDecoration(
                          "اكتب تفاصيل الرسالة هنا...", Icons.message),
                      validator: (v) =>
                          v!.isEmpty ? "محتوى الرسالة مطلوب" : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSchedulingSection(brandRed),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _handleSendOrSchedule,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                        _isScheduled ? "تأكيد الجدولة" : "إرسال الآن للجميع",
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveAsTemplate,
                    icon: Icon(Icons.save, color: brandRed),
                    label: Text("حفظ قالب",
                        style: TextStyle(fontFamily: 'Cairo', color: brandRed)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: brandRed),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- المكونات المساعدة (بدون أي تغيير في المنطق) ---

  Widget _buildTemplateSelector(Color brandRed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("قوالب سريعة",
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 10),
        SizedBox(
          height: 45,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('notification_templates')
                .select()
                .order('created_at'),
            builder: (context, snapshot) {
              final templates = snapshot.data ?? [];
              if (templates.isEmpty) {
                return const Text("لا توجد قوالب محفوظة",
                    style: TextStyle(fontSize: 12, color: Colors.grey));
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    label: Text(templates[i]['title'],
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _titleController.text = templates[i]['title'];
                        _bodyController.text = templates[i]['body'];
                      });
                    },
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                    avatar: Icon(Icons.copy, size: 14, color: brandRed),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSelector(Color brandRed) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEDEFF3))),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("نوع الاستهداف",
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _targetButton("عام", "all", Icons.groups),
                _targetButton("خاص", "specific", Icons.person_search),
                _targetButton("أقسام", "segment", Icons.pie_chart),
              ],
            ),
            if (_targetType == 'specific') ...[
              const SizedBox(height: 20),
              _buildSpecificSearchField(brandRed),
            ],
            if (_targetType == 'segment') ...[
              const SizedBox(height: 20),
              _buildSegmentDropdown(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _targetButton(String label, String type, IconData icon) {
    bool isSel = _targetType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _targetType = type;
        _selectedTarget = null;
        _searchController.clear();
      }),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFFD32027) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, color: isSel ? Colors.white : Colors.grey, size: 24),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildSpecificSearchField(Color brandRed) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          onChanged: (v) => setState(() {
            _selectedTarget = null;
          }),
          decoration: _buildInputDecoration(
              "اكتب اسم المتجر أو العميل للبحث...", Icons.search),
        ),
        if (_searchController.text.trim().isNotEmpty && _selectedTarget == null)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDEFF3))),
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                supabase
                    .from('merchants')
                    .select('id, store_name')
                    .ilike('store_name', '%${_searchController.text.trim()}%')
                    .limit(10)
                    .catchError((e) => []),
                supabase
                    .from('profiles')
                    .select('id, name')
                    .ilike('name', '%${_searchController.text.trim()}%')
                    .limit(10)
                    .catchError((e) => []),
              ]),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(15),
                      child: LinearProgressIndicator());
                }

                final List results = [];
                if (snapshot.hasData) {
                  results.addAll(snapshot.data![0]);
                  results.addAll(snapshot.data![1]);
                }

                if (results.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(15),
                      child: Text("لا توجد نتائج مطابقة",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey)));
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: results.length,
                  separatorBuilder: (c, i) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (c, i) {
                    final item = results[i];
                    final bool isStore = item.containsKey('store_name');
                    final String displayName = isStore
                        ? item['store_name']
                        : (item['name'] ?? "بدون اسم");

                    return ListTile(
                      dense: true,
                      leading: Icon(isStore ? Icons.storefront : Icons.person,
                          color: isStore ? Colors.orange : Colors.blue,
                          size: 20),
                      title: Text(displayName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(isStore ? "متجر" : "عميل",
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      onTap: () => setState(() {
                        _selectedTarget = item;
                        _searchController.text = displayName;
                      }),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSegmentDropdown() {
    return DropdownButtonFormField<String>(
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.black),
      decoration: _buildInputDecoration("اختر القسم", Icons.filter_alt),
      value: _selectedSegment,
      items: const [
        DropdownMenuItem(value: "all_merchants", child: Text("جميع التجار")),
        DropdownMenuItem(value: "all_customers", child: Text("جميع العملاء")),
        DropdownMenuItem(
            value: "active_merchants", child: Text("المتاجر الفعالة")),
        DropdownMenuItem(
            value: "inactive_merchants", child: Text("المتاجر غير الفعالة")),
        DropdownMenuItem(value: "active_users", child: Text("العملاء النشطون")),
        DropdownMenuItem(value: "idle_users", child: Text("العملاء الخاملون")),
      ],
      onChanged: (v) => setState(() => _selectedSegment = v),
    );
  }

  Widget _buildSchedulingSection(Color brandRed) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEDEFF3))),
      child: SwitchListTile(
        activeColor: brandRed,
        title: const Text("تفعيل جدولة الإرسال",
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        secondary: Icon(Icons.event_available,
            color: _isScheduled ? brandRed : Colors.grey),
        value: _isScheduled,
        onChanged: (v) async {
          if (v) {
            final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime(2027),
                builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(primary: brandRed)),
                    child: child!));
            if (!mounted) return;
            final time = await showTimePicker(
                context: context, initialTime: TimeOfDay.now());
            if (date != null && time != null) {
              setState(() {
                _scheduledDate = date;
                _scheduledTime = time;
                _isScheduled = true;
              });
            } else {
              setState(() => _isScheduled = false);
            }
          } else {
            setState(() => _isScheduled = false);
          }
        },
        subtitle: _isScheduled && _scheduledDate != null
            ? Text(
                "موعد الإرسال: ${intl.DateFormat('yyyy/MM/dd').format(_scheduledDate!)} - ${_scheduledTime!.format(context)}",
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold))
            : const Text("سيتم الإرسال فوراً عند الضغط على الزر",
                style: TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildLogsTab(Color brandRed) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _logsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(color: brandRed));
        }

        final logs = snapshot.data!;

        if (logs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.history_rounded,
                    size: 58, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                const Text("لا يوجد سجل إشعارات بعد",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        color: Colors.grey)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              int cols = 3;
              if (c.maxWidth < 560) {
                cols = 1;
              } else if (c.maxWidth < 900) {
                cols = 2;
              }
              final w = (c.maxWidth - gap * (cols - 1)) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: logs
                    .map((item) => SizedBox(
                        width: w, child: _logCard(item, brandRed)))
                    .toList(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _logCard(Map<String, dynamic> item, Color brandRed) {
    final bool isSent = item['status'] == 'sent';
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSent ? Colors.green : Colors.blue)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isSent
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  size: 16,
                  color: isSent ? Colors.green : Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (item['title'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            (item['body'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.8,
                color: Colors.grey.shade600),
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSent ? Colors.green : Colors.blue)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  isSent ? 'أُرسل' : 'مجدول',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSent ? Colors.green : Colors.blue),
                ),
              ),
              const Spacer(),
              if (created != null)
                Text(
                  intl.DateFormat('yyyy/MM/dd · HH:mm').format(created),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 12.5, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFEDEFF3))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFEDEFF3))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD32027), width: 1.4)),
    );
  }
}
