// site/src/pages/api/payments/callback.ts
// MyFatoorah يعيد العميل هنا بعد الدفع ومعه ?paymentId=...
import type { NextApiRequest, NextApiResponse } from 'next';
import { syncPayment } from '../../../lib/myfatoorah';

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string,
  );
}

function sendPage(res: NextApiResponse, ok: boolean, message: string, total?: number) {
  const panelUrl = process.env.PANEL_URL ?? '';
  const color = ok ? '#4CAF50' : '#D32027';
  const icon = ok ? '&#10003;' : '&#10005;';
  const title = ok ? 'تم الدفع بنجاح' : 'لم يكتمل الدفع';
  const amount =
    typeof total === 'number' ? `<p class="amount">${total.toFixed(2)} ر.س</p>` : '';
  const back = panelUrl
    ? `<a class="btn" href="${escapeHtml(panelUrl)}">العودة إلى لوحة التحكم</a>`
    : '';

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(`<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — رد ماركت</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap" rel="stylesheet">
<style>
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
       background:#F7F8FA;font-family:'Cairo',Tahoma,Arial,sans-serif;color:#1F2937}
  .card{background:#fff;border:1px solid #EDEFF3;border-radius:14px;padding:32px 28px;
        width:min(380px,90vw);text-align:center}
  .icon{width:56px;height:56px;border-radius:50%;margin:0 auto 12px;display:flex;
        align-items:center;justify-content:center;font-size:28px;color:#fff;background:${color}}
  h1{font-size:18px;margin:0 0 6px}
  p{margin:4px 0;color:#757575;font-size:14px}
  .amount{color:#1F2937;font-weight:700;font-size:16px}
  .btn{display:block;margin-top:20px;height:44px;line-height:44px;border-radius:11px;
       background:#D32027;color:#fff;text-decoration:none;font-weight:700}
</style>
</head>
<body>
  <div class="card">
    <div class="icon">${icon}</div>
    <h1>${title}</h1>
    ${amount}
    <p>${escapeHtml(message)}</p>
    ${back}
  </div>
</body>
</html>`);
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const mfPaymentId = typeof req.query.paymentId === 'string' ? req.query.paymentId : '';
  if (!mfPaymentId) return sendPage(res, false, 'رابط غير صالح');

  const r = await syncPayment(mfPaymentId, 'callback');
  // النجاح يُعرض حسب الدفع نفسه؛ إن تأخرت إضافة الرصيد يكملها الـ webhook
  return sendPage(res, r.paid, r.message, r.total);
}
