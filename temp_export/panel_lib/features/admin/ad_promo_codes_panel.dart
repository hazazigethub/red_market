import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/rm_pickers.dart';

/// أكواد الإعلانات والحملات — جدول banner_promo_codes
/// كود بنسبة 100% يغني عن شحن المحفظة
class AdPromoCodesPanel extends StatefulWidget {
  const AdPromoCodesPanel({super.key});

  @override
  State<AdPromoCodesPanel> createState() => _AdPromoCodesPanelState();
}

class _AdPromoCodesPanelState extends State<AdPromoCodesPanel> {
  static const Color brandRed = Color(0xFFD32027);
  static const Color line = Color(0xFFEDEFF3);

  static const Map<String, String> _scopes = {
    'all': 'كل الإعلانات والحملات',
    'banner': 'البنرات الأسبوعية',
    'splash': 'إعلان الشاشة الرئيسية',
    'campaign': 'الحملات الموسمية',
  };

  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _percentCtrl = TextEditingController(text: '100');
  final _maxUsesCtrl = TextEditingController();
  final _popupViewsCtrl = TextEditingController();

  String _scope = 'all';
  DateTime? _expiry;
  bool _showPopup = true;
  bool _saving = false;

  List<Map<String, dynamic>> _codes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _percentCtrl.dispose();
    _maxUsesCtrl.dispose();
    _popupViewsCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _load() async {
    try {
      final res = await supabase
          .from('banner_promo_codes')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _codes = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load ad codes error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final maxUses = int.tryParse(_maxUsesCtrl.text.trim());
      final popupViews = int.tryParse(_popupViewsCtrl.text.trim());
      await supabase.from('banner_promo_codes').insert({
        'code': _codeCtrl.text.trim().toUpperCase(),
        'discount_percent': int.parse(_percentCtrl.text.trim()),
        'applies_to': _scope,
        'max_uses': (maxUses != null && maxUses > 0) ? maxUses : null,
        'expiry_date': _expiry == null
            ? null
            : DateTime(_expiry!.year, _expiry!.month, _expiry!.day, 23, 59, 59)
                .toUtc()
                .toIso8601String(),
        'is_active': true,
        'show_popup': _showPopup,
        'popup_max_views': (_showPopup && popupViews != null && popupViews > 0)
            ? popupViews
            : null,
      });
      _codeCtrl.clear();
      _maxUsesCtrl.clear();
      _popupViewsCtrl.clear();
      _percentCtrl.text = '100';
      setState(() {
        _scope = 'all';
        _expiry = null;
        _showPopup = true;
      });
      await _load();
      _snack('تم حفظ الكود', Colors.green);
    } catch (e) {
      _snack('تعذر الحفظ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePopup(Map<String, dynamic> c) async {
    try {
      await supabase
          .from('banner_promo_codes')
          .update({'show_popup': c['show_popup'] != true}).eq('id', c['id']);
      await _load();
    } catch (e) {
      _snack('تعذر التحديث: $e', Colors.red);
    }
  }

  Future<void> _toggle(Map<String, dynamic> c, bool v) async {
    try {
      await supabase
          .from('banner_promo_codes')
          .update({'is_active': v}).eq('id', c['id']);
      await _load();
    } catch (e) {
      _snack('تعذر التحديث: $e', Colors.red);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text('حذف الكود ${c['code']}؟',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف',
                  style: TextStyle(fontFamily: 'Cairo', color: brandRed)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('banner_promo_codes').delete().eq('id', c['id']);
      await _load();
    } catch (e) {
      _snack('تعذر الحذف: $e', Colors.red);
    }
  }

  // ===================== الواجهة =====================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _form(),
        const SizedBox(height: 24),
        _list(),
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: brandRed, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _form() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _scope,
              isExpanded: true,
              decoration: _dec('يُطبَّق على', Icons.campaign_outlined),
              items: _scopes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontFamily: 'Cairo')),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _scope = v ?? 'all'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeCtrl,
              textDirection: TextDirection.ltr,
              decoration:
                  _dec('رمز الكود', Icons.confirmation_number_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _percentCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('نسبة الخصم (%)', Icons.percent_rounded),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1 || n > 100) return 'من 1 إلى 100';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxUsesCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('الحد الأقصى للاستخدام (فارغ = بلا حد)',
                  Icons.repeat_rounded),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                return (n == null || n < 1) ? 'رقم صحيح أكبر من صفر' : null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () async {
                final d = await rmPickDate(
                  context,
                  initial: _expiry,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _expiry = d);
              },
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 19, color: Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Text(
                      _expiry == null
                          ? 'تاريخ الانتهاء (فارغ = بلا انتهاء)'
                          : 'ينتهي ${DateFormat('yyyy-MM-dd').format(_expiry!)}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: _expiry == null
                              ? Colors.grey.shade600
                              : Colors.black87),
                    ),
                    const Spacer(),
                    if (_expiry != null)
                      InkWell(
                        onTap: () => setState(() => _expiry = null),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Icon(Icons.web_asset_rounded,
                      size: 19, color: Colors.grey.shade500),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('إظهار الكود للتجار في نافذة منبثقة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _showPopup,
                      activeColor: brandRed,
                      onChanged: (v) => setState(() => _showPopup = v),
                    ),
                  ),
                ],
              ),
            ),
            if (_showPopup) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _popupViewsCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec(
                    'مرات الظهور لكل تاجر (فارغ = حتى انتهاء الكود)',
                    Icons.visibility_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  return (n == null || n < 1) ? 'رقم صحيح أكبر من صفر' : null;
                },
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_saving ? 'جاري الحفظ...' : 'حفظ الكود',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }
    if (_codes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Text('لا توجد أكواد إعلانات بعد',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        ),
      );
    }
    return Column(
      children: _codes.map(_row).toList(),
    );
  }

  Widget _row(Map<String, dynamic> c) {
    final active = c['is_active'] == true;
    final used = (c['used_count'] as num?)?.toInt() ?? 0;
    final max = (c['max_uses'] as num?)?.toInt();
    final exp = c['expiry_date'] == null
        ? 'بلا انتهاء'
        : 'ينتهي ${DateFormat('yyyy-MM-dd').format(DateTime.parse(c['expiry_date']).toLocal())}';
    final scope = _scopes[c['applies_to']] ?? c['applies_to'].toString();
    final popup = c['show_popup'] == true;
    final popupViews = (c['popup_max_views'] as num?)?.toInt();
    final popupText = !popup
        ? 'لا يظهر للتجار'
        : (popupViews == null
            ? 'يظهر للتجار حتى انتهائه'
            : 'يظهر لكل تاجر $popupViews مرات');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFBE9EA) : const Color(0xFFF1F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${c['discount_percent'] ?? 0}%',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: active ? brandRed : Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['code'] ?? ''}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(
                  '$scope · استُخدم $used${max != null ? ' من $max' : ''} · $exp',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600),
                ),
                Text(
                  popupText,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: popup ? brandRed : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: popup ? 'إخفاء النافذة عن التجار' : 'إظهار النافذة للتجار',
            icon: Icon(
                popup
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_outlined,
                size: 19,
                color: popup ? brandRed : Colors.grey),
            onPressed: () => _togglePopup(c),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: active,
              activeColor: brandRed,
              onChanged: (v) => _toggle(c, v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 19),
            onPressed: () => _delete(c),
          ),
        ],
      ),
    );
  }
}
