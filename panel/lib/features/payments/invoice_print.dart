// panel/lib/features/payments/invoice_print.dart
// يفتح الفاتورة أو الإيصال في تبويب جديد كصفحة قابلة للطباعة (وحفظها PDF من المتصفح)
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

/// kind: 'invoice' أو 'receipt'. يعيد رسالة خطأ أو null عند النجاح.
Future<String?> openFinanceDocument(String kind, String id) async {
  // نفتح التبويب فوراً (ضمن نقرة المستخدم) حتى لا يحظره المتصفح
  final win = web.window.open('', '_blank');

  try {
    final html = kind == 'invoice' ? await _invoiceHtml(id) : await _receiptHtml(id);
    final blob = web.Blob(
      <JSAny>[html.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    if (win != null) {
      win.location.href = url;
    } else {
      web.window.open(url, '_blank');
    }
    return null;
  } catch (e) {
    win?.close();
    return 'تعذّر فتح المستند';
  }
}

final _sb = Supabase.instance.client;

String _e(Object? v) => (v ?? '')
    .toString()
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _m(Object? v) => ((v as num?) ?? 0).toDouble().toStringAsFixed(2);

String _date(Object? raw, {bool time = false}) {
  final d = DateTime.tryParse((raw ?? '').toString())?.toLocal();
  if (d == null) return (raw ?? '').toString();
  final base = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  if (!time) return base;
  return '$base ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ===================== الفاتورة =====================

Future<String> _invoiceHtml(String id) async {
  final inv = await _sb.from('invoices').select().eq('id', id).single();
  final items = await _sb
      .from('invoice_items')
      .select()
      .eq('invoice_id', id)
      .order('created_at');

  final isTax = inv['is_tax_invoice'] == true;
  final cancelled = inv['status'] == 'cancelled';
  final title = isTax ? 'فاتورة ضريبية مبسطة' : 'فاتورة';
  final qr = (inv['qr_base64'] ?? '').toString();

  final rows = StringBuffer();
  for (final it in items) {
    rows.write('<tr>'
        '<td>${_e(it['description'])}</td>'
        '<td class="n">${_e(it['quantity'] ?? 1)}</td>'
        '<td class="n">${_m(it['unit_price'])}</td>'
        '<td class="n">${_m(it['line_total'])}</td>'
        '</tr>');
  }

  final totals = isTax
      ? '''
      <tr><td>المجموع قبل الضريبة</td><td class="n">${_m(inv['subtotal'])} ر.س</td></tr>
      <tr><td>ضريبة القيمة المضافة (${_e(inv['vat_percent'])}%)</td><td class="n">${_m(inv['vat_amount'])} ر.س</td></tr>
      <tr class="grand"><td>الإجمالي شامل الضريبة</td><td class="n">${_m(inv['total_amount'])} ر.س</td></tr>'''
      : '''
      <tr class="grand"><td>الإجمالي</td><td class="n">${_m(inv['total_amount'])} ر.س</td></tr>''';

  final seller = StringBuffer()
    ..write('<div class="party"><h3>البائع</h3>')
    ..write('<p class="name">${_e(inv['seller_name'] ?? 'رد ماركت')}</p>');
  if ((inv['seller_cr_number'] ?? '').toString().isNotEmpty) {
    seller.write('<p>السجل التجاري: ${_e(inv['seller_cr_number'])}</p>');
  }
  if ((inv['seller_address'] ?? '').toString().isNotEmpty) {
    seller.write('<p>${_e(inv['seller_address'])}</p>');
  }
  if (isTax) {
    seller.write('<p>الرقم الضريبي: ${_e(inv['seller_vat_number'])}</p>');
  }
  seller.write('</div>');

  final buyer = StringBuffer()
    ..write('<div class="party"><h3>العميل</h3>')
    ..write('<p class="name">${_e(inv['buyer_name'] ?? '—')}</p>');
  if (isTax && (inv['buyer_vat_number'] ?? '').toString().isNotEmpty) {
    buyer.write('<p>الرقم الضريبي: ${_e(inv['buyer_vat_number'])}</p>');
  }
  buyer.write('</div>');

  return _page(
    title: '$title ${_e(inv['invoice_number'])}',
    heading: title,
    number: _e(inv['invoice_number']),
    date: _date(inv['issued_at'] ?? inv['invoice_date'], time: true),
    cancelled: cancelled,
    body: '''
    <div class="parties">${seller.toString()}${buyer.toString()}</div>
    <table class="items">
      <thead><tr><th>الوصف</th><th class="n">الكمية</th><th class="n">سعر الوحدة</th><th class="n">المجموع</th></tr></thead>
      <tbody>$rows</tbody>
    </table>
    <div class="bottom">
      ${qr.isNotEmpty ? '<div id="qr" class="qr"></div>' : '<div></div>'}
      <table class="totals">$totals</table>
    </div>
    ${(inv['notes'] ?? '').toString().isNotEmpty ? '<p class="note">${_e(inv['notes'])}</p>' : ''}
    <p class="note">الحالة: ${cancelled ? 'ملغاة' : 'مدفوعة من رصيد المتجر'}</p>
    ''',
    qr: qr,
  );
}

// ===================== الإيصال =====================

Future<String> _receiptHtml(String id) async {
  final rc = await _sb
      .from('receipts')
      .select('*, payments(payment_method, myratoorah_payment_id, total_amount)')
      .eq('id', id)
      .single();
  final pay = (rc['payments'] as Map?) ?? {};

  final merchant = await _sb
      .from('merchants')
      .select('store_name')
      .eq('id', rc['merchant_id'])
      .maybeSingle();

  Map<String, dynamic>? settings;
  try {
    settings = await _sb
        .from('system_settings')
        .select('seller_name, seller_cr_number, seller_address')
        .order('id')
        .limit(1)
        .maybeSingle();
  } catch (_) {}

  final amount = rc['amount'] ?? pay['total_amount'];

  return _page(
    title: 'إيصال ${_e(rc['receipt_number'])}',
    heading: 'إيصال استلام',
    number: _e(rc['receipt_number']),
    date: _date(rc['receipt_date'], time: true),
    cancelled: false,
    body: '''
    <div class="parties">
      <div class="party"><h3>المستلِم</h3>
        <p class="name">${_e(settings?['seller_name'] ?? 'رد ماركت')}</p>
        ${(settings?['seller_cr_number'] ?? '').toString().isNotEmpty ? '<p>السجل التجاري: ${_e(settings?['seller_cr_number'])}</p>' : ''}
        ${(settings?['seller_address'] ?? '').toString().isNotEmpty ? '<p>${_e(settings?['seller_address'])}</p>' : ''}
      </div>
      <div class="party"><h3>من</h3>
        <p class="name">${_e(merchant?['store_name'] ?? '—')}</p>
      </div>
    </div>
    <table class="totals wide">
      <tr><td>البيان</td><td>شحن رصيد المتجر</td></tr>
      <tr><td>طريقة الدفع</td><td>${_e(pay['payment_method'] ?? 'بطاقة')}</td></tr>
      <tr><td>مرجع الدفع</td><td class="n">${_e(pay['myratoorah_payment_id'] ?? '—')}</td></tr>
      <tr class="grand"><td>المبلغ المستلم</td><td class="n">${_m(amount)} ر.س</td></tr>
    </table>
    <p class="note">هذا الإيصال يثبت استلام مبلغ مقدَّم لشحن الرصيد، وتصدر الفاتورة عند استخدام الرصيد في شراء خدمة.</p>
    ''',
    qr: '',
  );
}

// ===================== قالب الصفحة =====================

String _page({
  required String title,
  required String heading,
  required String number,
  required String date,
  required bool cancelled,
  required String body,
  required String qr,
}) {
  return '''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap" rel="stylesheet">
<style>
  *{box-sizing:border-box}
  body{margin:0;background:#F7F8FA;font-family:'Cairo',Tahoma,Arial,sans-serif;color:#1F2937;font-size:13px}
  .sheet{max-width:780px;margin:24px auto;background:#fff;border:1px solid #EDEFF3;border-radius:14px;padding:32px;position:relative;overflow:hidden}
  .head{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:2px solid #D32027;padding-bottom:16px;margin-bottom:20px}
  .brand{font-size:22px;font-weight:700;color:#D32027}
  .doc h1{margin:0;font-size:18px}
  .doc p{margin:2px 0;color:#757575}
  .parties{display:flex;gap:16px;margin-bottom:20px}
  .party{flex:1;background:#F7F8FA;border-radius:11px;padding:12px 14px}
  .party h3{margin:0 0 4px;font-size:12px;color:#757575;font-weight:400}
  .party p{margin:2px 0}
  .party .name{font-weight:700;font-size:14px}
  table{width:100%;border-collapse:collapse}
  .items th{background:#F7F8FA;font-weight:700;text-align:right;padding:10px;border-bottom:1px solid #EDEFF3}
  .items td{padding:10px;border-bottom:1px solid #EDEFF3}
  .n{text-align:left;direction:ltr;white-space:nowrap}
  th.n{text-align:left}
  .bottom{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;margin-top:16px}
  .totals{width:auto;min-width:300px}
  .totals.wide{width:100%}
  .totals td{padding:8px 10px;border-bottom:1px solid #EDEFF3}
  .totals td:first-child{color:#757575}
  .totals .grand td{font-weight:700;font-size:15px;color:#1F2937;border-bottom:none;border-top:2px solid #1F2937}
  .qr{width:140px;height:140px}
  .note{color:#757575;font-size:11.5px;margin-top:14px}
  .stamp{position:absolute;top:40%;left:50%;transform:translate(-50%,-50%) rotate(-20deg);font-size:72px;font-weight:700;color:rgba(211,32,39,.12);pointer-events:none}
  .actions{max-width:780px;margin:0 auto 24px;text-align:center}
  .actions button{height:44px;padding:0 28px;border:none;border-radius:11px;background:#D32027;color:#fff;font-family:inherit;font-size:14px;font-weight:700;cursor:pointer}
  @media print{
    body{background:#fff}
    .sheet{border:none;margin:0;max-width:none;border-radius:0}
    .actions{display:none}
  }
</style>
</head>
<body>
  <div class="sheet">
    ${cancelled ? '<div class="stamp">ملغاة</div>' : ''}
    <div class="head">
      <div class="brand">رد ماركت</div>
      <div class="doc">
        <h1>$heading</h1>
        <p>رقم: $number</p>
        <p>التاريخ: $date</p>
      </div>
    </div>
    $body
  </div>
  <div class="actions"><button onclick="window.print()">طباعة / حفظ PDF</button></div>
  ${qr.isEmpty ? '' : '''
  <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
  <script>
    new QRCode(document.getElementById("qr"), {text: "$qr", width: 140, height: 140, correctLevel: QRCode.CorrectLevel.M});
  </script>'''}
</body>
</html>''';
}
