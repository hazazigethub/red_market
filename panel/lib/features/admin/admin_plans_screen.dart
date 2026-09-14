import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('subscription_plans')
          .select()
          .order('is_active', ascending: false)
          .order('price');

      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Plans load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  /// عدد التجار المشتركين بباقة معيّنة
  Future<int> _subscriberCount(dynamic planId) async {
    try {
      final res = await supabase
          .from('profiles')
          .select('id')
          .eq('plan_id', planId);
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> plan) async {
    try {
      await supabase
          .from('subscription_plans')
          .update({'is_active': !(plan['is_active'] ?? false)})
          .eq('id', plan['id']);
      await _load();
    } catch (e) {
      _snack('تعذر التحديث', Colors.red);
    }
  }

  Future<void> _delete(Map<String, dynamic> plan) async {
    final count = await _subscriberCount(plan['id']);

    if (!mounted) return;

    if (count > 0) {
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('لا يمكن الحذف',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            content: Text(
              'يشترك بهذه الباقة $count تاجر. عطّلها بدل حذفها حتى لا تفقد سجلّاتهم.',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف الباقة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: Text(
            'سيتم حذف باقة "${plan['name']}" نهائياً. هل أنت متأكد؟',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await supabase
                      .from('subscription_plans')
                      .delete()
                      .eq('id', plan['id']);
                  await _load();
                  _snack('تم حذف الباقة', Colors.green);
                } catch (e) {
                  _snack('تعذر الحذف', Colors.red);
                }
              },
              child: const Text('حذف',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm({Map<String, dynamic>? plan}) {
    showDialog(
      context: context,
      builder: (_) => _PlanForm(
        plan: plan,
        onSaved: () {
          _load();
          _snack(plan == null ? 'تمت إضافة الباقة' : 'تم حفظ التعديلات',
              Colors.green);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('إدارة الباقات',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text('${_plans.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('باقة جديدة',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_plans.isEmpty)
                    _empty()
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        const gap = 14.0;
                        final cols = (c.maxWidth / 330).floor().clamp(1, 4);
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: _plans
                              .map((p) =>
                                  SizedBox(width: w, child: _planCard(p)))
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
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final active = plan['is_active'] ?? false;
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final days = (plan['duration_days'] as num?)?.toInt() ?? 30;
    final discount = (plan['discount_percent'] as num?)?.toInt() ?? 0;
    final features = (plan['features'] as List?) ?? [];
    final type = (plan['plan_type'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: active ? const Color(0xFFEDEFF3) : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (plan['name'] ?? 'باقة').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.black87 : Colors.grey),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (active ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  active ? 'مفعّلة' : 'معطّلة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.green : Colors.grey),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2),
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: active ? brandRed : Colors.grey),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('ر.س / $days يوم',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade600)),
              ),
              const Spacer(),
              if (discount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('خصم $discount%',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: brandRed)),
                ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 12),

          _line('النوع', type.isEmpty ? '—' : type),
          const SizedBox(height: 7),
          _line('حد العروض', '${plan['product_limit'] ?? 0}'),
          const SizedBox(height: 7),
          _line('حد الريلز', '${plan['reels_limit'] ?? 0}'),
          const SizedBox(height: 7),
          _line('عدد الميزات', '${features.length}'),
          const SizedBox(height: 7),
          FutureBuilder<int>(
            future: _subscriberCount(plan['id']),
            builder: (context, snap) =>
                _line('المشتركون', snap.hasData ? '${snap.data}' : '—'),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openForm(plan: plan),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('تعديل',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandRed,
                    side: BorderSide(color: brandRed),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _toggleActive(plan),
                tooltip: active ? 'تعطيل' : 'تفعيل',
                icon: Icon(
                    active
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    size: 26,
                    color: active ? Colors.green : Colors.grey),
              ),
              IconButton(
                onPressed: () => _delete(plan),
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.card_membership_outlined,
              size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا توجد باقات',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ===================== نموذج الإضافة والتعديل =====================

class _PlanForm extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback onSaved;

  const _PlanForm({this.plan, required this.onSaved});

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  static const Color brandRed = Color(0xFFD32027);

  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _days;
  late TextEditingController _products;
  late TextEditingController _reels;
  late TextEditingController _discount;

  String _type = 'basic';
  bool _basicReports = true;
  bool _detailedReports = false;
  bool _active = true;
  bool _saving = false;

  List<String> _features = [];
  final _featureCtrl = TextEditingController();

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;

    _name = TextEditingController(text: p?['name']?.toString() ?? '');
    _price = TextEditingController(
        text: (p?['price'] as num?)?.toString() ?? '');
    _days = TextEditingController(
        text: (p?['duration_days'] as num?)?.toString() ?? '30');
    _products = TextEditingController(
        text: (p?['product_limit'] as num?)?.toString() ?? '0');
    _reels = TextEditingController(
        text: (p?['reels_limit'] as num?)?.toString() ?? '0');
    _discount = TextEditingController(
        text: (p?['discount_percent'] as num?)?.toString() ?? '0');

    _type = (p?['plan_type'] ?? 'basic').toString();
    _basicReports = p?['has_basic_reports'] ?? true;
    _detailedReports = p?['has_detailed_reports'] ?? false;
    _active = p?['is_active'] ?? true;
    _features =
        ((p?['features'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _days.dispose();
    _products.dispose();
    _reels.dispose();
    _discount.dispose();
    _featureCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final payload = {
      'name': _name.text.trim(),
      'price': double.tryParse(_price.text.trim()) ?? 0,
      'duration_days': int.tryParse(_days.text.trim()) ?? 30,
      'product_limit': int.tryParse(_products.text.trim()) ?? 0,
      'reels_limit': int.tryParse(_reels.text.trim()) ?? 0,
      'discount_percent': int.tryParse(_discount.text.trim()) ?? 0,
      'plan_type': _type,
      'has_basic_reports': _basicReports,
      'has_detailed_reports': _detailedReports,
      'is_active': _active,
      'features': _features,
    };

    try {
      if (_isEdit) {
        await supabase
            .from('subscription_plans')
            .update(payload)
            .eq('id', widget.plan!['id']);
      } else {
        await supabase.from('subscription_plans').insert(payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Save plan error: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر الحفظ، تحقق من البيانات',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  color: brandRed,
                  child: Row(
                    children: [
                      Icon(
                          _isEdit
                              ? Icons.edit_rounded
                              : Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isEdit ? 'تعديل الباقة' : 'باقة جديدة',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(_name, 'اسم الباقة'),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                  child: _field(_price, 'السعر',
                                      number: true)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _field(_days, 'المدة (أيام)',
                                      number: true)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                  child: _field(_products, 'حد العروض',
                                      number: true)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _field(_reels, 'حد الريلز',
                                      number: true)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                  child: _field(_discount, 'نسبة الخصم %',
                                      number: true, required: false)),
                              const SizedBox(width: 12),
                              Expanded(child: _typeDropdown()),
                            ],
                          ),
                          const SizedBox(height: 18),

                          _switchRow('تقارير أساسية', _basicReports,
                              (v) => setState(() => _basicReports = v)),
                          _switchRow('تقارير تفصيلية', _detailedReports,
                              (v) => setState(() => _detailedReports = v)),
                          _switchRow('الباقة مفعّلة', _active,
                              (v) => setState(() => _active = v)),

                          const SizedBox(height: 18),
                          const Divider(color: Color(0xFFEDEFF3)),
                          const SizedBox(height: 14),

                          const Text('ميزات الباقة',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _featureCtrl,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo', fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'أضف ميزة',
                                    hintStyle: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: Colors.grey.shade400),
                                    filled: true,
                                    fillColor: const Color(0xFFF7F8FA),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide.none),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                  ),
                                  onSubmitted: (_) => _addFeature(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: _addFeature,
                                icon: const Icon(Icons.add_circle_rounded,
                                    color: brandRed, size: 28),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          ..._features.asMap().entries.map((e) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 15, color: brandRed),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(e.value,
                                          style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12.5)),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _features.removeAt(e.key)),
                                      child: Icon(Icons.close,
                                          size: 16,
                                          color: Colors.grey.shade400),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Color(0xFFEDEFF3))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء',
                              style: TextStyle(
                                  fontFamily: 'Cairo', color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                              _saving
                                  ? 'جاري الحفظ...'
                                  : (_isEdit ? 'حفظ التعديلات' : 'إضافة'),
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addFeature() {
    final t = _featureCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _features.add(t);
      _featureCtrl.clear();
    });
  }

  Widget _field(TextEditingController c, String label,
      {bool number = false, bool required = true}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null
          : null,
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _type,
      style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: 'النوع',
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: const [
        DropdownMenuItem(
            value: 'basic',
            child:
                Text('أساسية', style: TextStyle(fontFamily: 'Cairo'))),
        DropdownMenuItem(
            value: 'growth',
            child: Text('نمو', style: TextStyle(fontFamily: 'Cairo'))),
        DropdownMenuItem(
            value: 'pro',
            child:
                Text('احترافية', style: TextStyle(fontFamily: 'Cairo'))),
      ],
      onChanged: (v) => setState(() => _type = v ?? 'basic'),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: brandRed,
        ),
      ],
    );
  }
}
