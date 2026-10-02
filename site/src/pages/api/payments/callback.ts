// site/src/pages/api/payments/callback.ts
// MyFatoorah يعيد العميل هنا بعد الدفع ومعه ?paymentId=...
// نتحقق من الحالة من MyFatoorah مباشرة (GET /v3/payments/{paymentId}) ثم نحدّث Supabase.
import type { NextApiRequest, NextApiResponse } from 'next';
import { createClient } from '@supabase/supabase-js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

  const mfBase = (process.env.MYFATOORAH_BASE_URL ?? '').replace(/\/+$/, '');
  const mfKey = process.env.MYFATOORAH_API_KEY ?? '';
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
  if (!mfBase || !mfKey || !supabaseUrl || !serviceKey) {
    return sendPage(res, false, 'إعدادات الخادم ناقصة');
  }

  // ===== حالة الدفع من MyFatoorah =====
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let data: any;
  try {
    const mfRes = await fetch(`${mfBase}/v3/payments/${encodeURIComponent(mfPaymentId)}`, {
      headers: { Authorization: `Bearer ${mfKey}`, Accept: 'application/json' },
    });
    const json = await mfRes.json().catch(() => null);
    if (!mfRes.ok || !json?.IsSuccess || !json?.Data) {
      return sendPage(res, false, 'تعذّر التحقق من حالة الدفع');
    }
    data = json.Data;
  } catch {
    return sendPage(res, false, 'تعذّر الاتصال بـ MyFatoorah');
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // ===== إيجاد الدفعة: برقم فاتورة MyFatoorah، ثم بالمعرّف الخارجي =====
  const invoiceId = String(data.Invoice?.Id ?? '');
  const externalId = String(data.Invoice?.ExternalIdentifier ?? '');

  let payment: { id: string; status: string; total_amount: number } | null = null;
  if (invoiceId) {
    const { data: p } = await supabase
      .from('payments')
      .select('id, status, total_amount')
      .eq('myratoorah_order_id', invoiceId)
      .maybeSingle();
    payment = p;
  }
  if (!payment && UUID_RE.test(externalId)) {
    const { data: p } = await supabase
      .from('payments')
      .select('id, status, total_amount')
      .eq('id', externalId)
      .maybeSingle();
    payment = p;
  }
  if (!payment) return sendPage(res, false, 'لم يتم العثور على الدفعة');

  const paid = data.Invoice?.Status === 'PAID';
  const total = Number(payment.total_amount);

  // لا نغيّر دفعة مكتملة مسبقاً
  if (payment.status === 'completed') {
    return sendPage(res, true, 'تم تسجيل هذه الدفعة مسبقاً', total);
  }

  const newStatus = paid ? 'completed' : 'failed';
  const failureReason = paid
    ? null
    : data.Transaction?.Error?.Message || data.Invoice?.Status || 'لم يكتمل الدفع';

  await supabase
    .from('payments')
    .update({
      status: newStatus,
      myratoorah_payment_id: data.Transaction?.PaymentId ?? mfPaymentId,
      payment_method: data.Transaction?.PaymentMethod ?? null,
      failure_reason: failureReason,
      ...(paid ? { completed_at: new Date().toISOString() } : {}),
    })
    .eq('id', payment.id);

  await supabase.from('payment_history').insert({
    payment_id: payment.id,
    previous_status: payment.status,
    new_status: newStatus,
    description: paid ? 'دفع ناجح عبر MyFatoorah' : `فشل الدفع: ${failureReason}`,
    myratoorah_response: data,
  });

  return paid
    ? sendPage(res, true, 'شكراً لك، تم استلام المبلغ', total)
    : sendPage(res, false, String(failureReason), total);
}
