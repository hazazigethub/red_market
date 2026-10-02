// site/src/pages/api/webhooks/payment.ts
// يستقبل إشعارات MyFatoorah (Webhook V2، ويقبل V1).
// لا نثق بمحتوى الإشعار: نأخذ منه رقم الدفع فقط، ثم نسأل MyFatoorah مباشرة عن الحالة.
// التوقيع (MyFatoorah-Signature) يُتحقق منه عند ضبط MYFATOORAH_WEBHOOK_SECRET.
import type { NextApiRequest, NextApiResponse } from 'next';
import { createHmac, timingSafeEqual } from 'crypto';
import { supabaseAdmin, syncPayment } from '../../../lib/myfatoorah';

// ترتيب حقول التوقيع لحدث PAYMENT_STATUS_CHANGED حسب توثيق MyFatoorah (V2)
const SIGNATURE_FIELDS = [
  'Invoice.Id',
  'Invoice.Status',
  'Transaction.Status',
  'Transaction.PaymentId',
  'Invoice.ExternalIdentifier',
];

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function pick(obj: any, path: string): string {
  const v = path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
  return v == null ? '' : String(v);
}

function safeEqual(a: string, b: string) {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function verifyV2Signature(data: any, header: string, secret: string): boolean {
  const message = SIGNATURE_FIELDS.map((f) => `${f}=${pick(data, f)}`).join(',');
  const digest = createHmac('sha256', Buffer.from(secret, 'utf8'))
    .update(Buffer.from(message, 'utf8'))
    .digest();
  return safeEqual(digest.toString('base64'), header) || safeEqual(digest.toString('hex'), header);
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const body: any = req.body ?? {};
  const data = body.Data ?? {};
  const isV2 = !!body.Event;
  const eventName: string = isV2
    ? String(body.Event?.Name ?? '')
    : String(body.EventType ?? '');

  // ===== التوقيع (V2) =====
  const secret = process.env.MYFATOORAH_WEBHOOK_SECRET ?? '';
  const signature = String(req.headers['myfatoorah-signature'] ?? '');
  if (secret && isV2) {
    if (!signature || !verifyV2Signature(data, signature, secret)) {
      return res.status(401).json({ error: 'invalid signature' });
    }
  }

  // نتعامل مع أحداث حالة الدفع فقط
  const isPaymentEvent = isV2 ? eventName === 'PAYMENT_STATUS_CHANGED' : eventName === '1';
  if (!isPaymentEvent) return res.status(200).json({ ignored: true });

  const mfPaymentId = String(data.Transaction?.PaymentId ?? data.PaymentId ?? '');
  if (!mfPaymentId) return res.status(200).json({ ignored: true, reason: 'no PaymentId' });

  const supabase = supabaseAdmin();
  if (!supabase) return res.status(500).json({ error: 'server config' });

  // ===== منع المعالجة المكررة =====
  const webhookId = String(body.Event?.Reference ?? `${eventName}-${mfPaymentId}-${pick(data, 'Transaction.Status') || pick(data, 'TransactionStatus')}`);

  const { data: existing } = await supabase
    .from('payment_webhooks')
    .select('id, status')
    .eq('webhook_id', webhookId)
    .maybeSingle();

  if (existing?.status === 'processed') {
    return res.status(200).json({ duplicate: true });
  }

  let rowId = existing?.id as string | undefined;
  if (!rowId) {
    const { data: inserted } = await supabase
      .from('payment_webhooks')
      .insert({
        webhook_id: webhookId,
        event_type: eventName || 'unknown',
        payload: body,
        status: 'pending',
      })
      .select('id')
      .single();
    rowId = inserted?.id;
  }

  // ===== المزامنة مع MyFatoorah =====
  const r = await syncPayment(mfPaymentId, 'webhook');

  if (rowId) {
    await supabase
      .from('payment_webhooks')
      .update({
        status: r.ok ? 'processed' : 'failed',
        error_message: r.ok ? null : r.message,
        payment_id: r.paymentRowId ?? null,
        processed_at: new Date().toISOString(),
      })
      .eq('id', rowId);
  }

  // 500 عند الفشل حتى تعيد MyFatoorah المحاولة
  return r.ok
    ? res.status(200).json({ success: true, paid: r.paid })
    : res.status(500).json({ success: false, error: r.message });
}
