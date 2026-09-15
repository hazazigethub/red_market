import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscountCodesScreen extends StatefulWidget {
  const DiscountCodesScreen({super.key});

  @override
  State<DiscountCodesScreen> createState() => _DiscountCodesScreenState();
}

class _DiscountCodesScreenState extends State<DiscountCodesScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final Color brandRed = const Color(0xFFD32027);
  int _activeTab = 0;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  // تم تغيير النوع ليكون dynamic أو int ليتناسب مع ID الباقة من سوبابيس
  dynamic _selectedPlanId = _allPlans;

  /// قيمة تدل على أن الكود يسري على كل الباقات
  static const String _allPlans = '__all__';

  /// أسماء الباقات لعرضها في بطاقات الأكواد
  final Map<dynamic, String> _planNames = {};

  @override
  void initState() {
    super.initState();
    _loadPlanNames();
  }

  Future<void> _loadPlanNames() async {
    try {
      final res =
          await supabase.from('subscription_plans').select('id, name');
      if (!mounted) return;
      setState(() {
        for (final p in List<Map<String, dynamic>>.from(res)) {
          _planNames[p['id']] = (p['name'] ?? '').toString();
        }
      });
    } catch (_) {
      // تجاهل
    }
  }

  Future<void> _saveCode() async {
    if (_formKey.currentState!.validate() && _endDate != null) {
      try {
        await supabase.from('promo_codes').insert({
          'code': _codeController.text,
          'discount_percent': int.tryParse(_valueController.text) ?? 0,
          // فارغ يعني أن الكود يسري على كل الباقات
          'plan_id': _selectedPlanId == _allPlans ? null : _selectedPlanId,
          'is_active': true,
          'expiry_date': _endDate!.toIso8601String(),
          // ملاحظة: تم إخفاء start_date لأن الحقل غير موجود في جدول promo_codes لديك
        });

        _codeController.clear();
        _valueController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
          _selectedPlanId = _allPlans;
          _activeTab = 1;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الكود بنجاح'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleCodeStatus(String id, bool currentStatus) async {
    try {
      await supabase
          .from('promo_codes')
          .update({'is_active': currentStatus}).eq('id', id);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ في تحديث الحالة: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCode(String id) async {
    try {
      await supabase.from('promo_codes').delete().eq('id', id);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ في الحذف: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: brandRed,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF7F8FA),
        child: Column(
            children: [
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Row(
                      children: [
                        _buildCompactSquareCard(
                          title: "إنشاء كود",
                          icon: Icons.add_circle_outline,
                          index: 0,
                        ),
                        const SizedBox(width: 10),
                        _buildCompactSquareCard(
                          title: "الأكواد الحالية",
                          icon: Icons.format_list_bulleted_rounded,
                          index: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _activeTab == 0
                          ? _buildCreateView()
                          : _buildListView(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSquareCard(
      {required String title, required IconData icon, required int index}) {
    final on = _activeTab == index;

    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
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
              title,
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

  Widget _buildCreateView() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('subscription_plans')
                .stream(primaryKey: ['id']).order('created_at'),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text("خطأ في تحميل الباقات");
              if (!snapshot.hasData) return const LinearProgressIndicator();

              final plans = snapshot.data!;

              // التحقق من وجود الـ ID في القائمة لتجنب مشاكل الـ Dropdown
              final bool valueExists = _selectedPlanId == _allPlans ||
                  plans.any((p) => p['id'] == _selectedPlanId);
              final dynamic currentValue =
                  valueExists ? _selectedPlanId : _allPlans;

              return DropdownButtonFormField<dynamic>(
                initialValue: currentValue,
                isExpanded: true,
                decoration: _inputDecoration(
                    icon: Icons.list_alt_rounded, label: "الباقة"),
                items: [
                  const DropdownMenuItem<dynamic>(
                    value: _allPlans,
                    child: Text('كل الباقات',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                  ),
                  ...plans.map((p) => DropdownMenuItem<dynamic>(
                        value: p['id'],
                        child: Text(p['name'] ?? '',
                            style: const TextStyle(fontFamily: 'Cairo')),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedPlanId = v),
              );
            },
          ),
          _buildInput(
              icon: Icons.confirmation_number_outlined,
              label: "رمز الكود",
              controller: _codeController),
          _buildInput(
              icon: Icons.percent_rounded,
              label: "نسبة الخصم (%)",
              controller: _valueController,
              isNumber: true),
          const SizedBox(height: 10),
          _buildDateTile(
            label: _startDate == null
                ? "تاريخ بدء الكود"
                : DateFormat('yyyy-MM-dd').format(_startDate!),
            icon: Icons.calendar_today_outlined,
            onTap: () => _selectDate(context, true),
          ),
          const SizedBox(height: 10),
          _buildDateTile(
            label: _endDate == null
                ? "تاريخ انتهاء الكود"
                : DateFormat('yyyy-MM-dd').format(_endDate!),
            icon: Icons.calendar_month_outlined,
            onTap: () => _selectDate(context, false),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveCode,
              style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text("حفظ ونشر الكود",
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('promo_codes')
            .stream(primaryKey: ['id']).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final codes = snapshot.data!;

          if (codes.isEmpty) {
            return const Center(
                child: Text("لا توجد أكواد حالياً",
                    style: TextStyle(fontFamily: 'Cairo')));
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: codes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final item = codes[index];
              return Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: const Color(0xFFEDEFF3))),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${item['discount_percent'] ?? 0}%",
                              style: TextStyle(
                                color: item['is_active']
                                    ? brandRed
                                    : Colors.grey[400],
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(Icons.confirmation_number_rounded,
                                size: 26,
                                color: item['is_active']
                                    ? brandRed
                                    : Colors.grey[400]),
                            const SizedBox(height: 6),
                            Text(
                              item['code'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              item['plan_id'] == null
                                  ? 'كل الباقات'
                                  : (_planNames[item['plan_id']] ??
                                      'باقة ${item['plan_id']}'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontFamily: 'Cairo',
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                "ينتهي: ${item['expiry_date'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(item['expiry_date'])) : ''}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontFamily: 'Cairo',
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEDEFF3)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            onPressed: () => _deleteCode(item['id'].toString()),
                          ),
                          Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              value: item['is_active'] ?? false,
                              activeColor: brandRed,
                              onChanged: (val) =>
                                  _toggleCodeStatus(item['id'].toString(), val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        });
  }

  Widget _buildDateTile(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white),
        child: Row(
          children: [
            Icon(icon, color: brandRed, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: brandRed),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required IconData icon, required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFEDEFF3))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFEDEFF3))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: brandRed, width: 1.4)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildInput(
      {required IconData icon,
      required String label,
      required TextEditingController controller,
      bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(icon: icon, label: label),
        validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    super.dispose();
  }
}
