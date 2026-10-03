// site/src/lib/myfatoorah.ts
// منطق مشترك: جلب حالة الدفع من MyFatoorah وتحديث Supabase.
// يستخدمه callback (رجوع العميل) و webhook (إشعار MyFatoorah) — مصدر الحقيقة واحد.
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function mfConfig() {
  return {
    base: (process.env.MYFATOORAH_BASE_URL ?? '').replace(/\/+$/, ''),
    key: process.env.MYFATOORAH_API_KEY ?? '',
  };
}

export function supabaseAdmin(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
  if (!url || !key) return null;
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export type SyncResult = {
  ok: boolean; // تمت المعالجة كاملة (بما فيها إضافة الرصيد) — false يجعل webhook يعيد المحاولة
  paid: boolean; // الدفع مكتمل
  message: string;
  paymentRowId?: string;
  total?: number;
};

/**
 * يجلب حالة الدفع من MyFatoorah (GET /v3/payments/{paymentId})
 * ثم يحدّث جدول payments ويسجّل في payment_history.
 * لا يحوّل دفعة مكتملة إلى غير مكتملة أبداً.
 */
export async function syncPayment(
  mfPaymentId: string,
  source: 'callback' | 'webhook',
  hintRowId?: string, // معرّف الدفعة من صفحة الدفع المدمجة (احتياط إن لم يُرجع المعرّف الخارجي)
): Promise<SyncResult> {
  const { base, key } = mfConfig();
  const supabase = supabaseAdmin();
  if (!base || !key || !supabase) {
    return { ok: false, paid: false, message: 'إعدادات الخادم ناقصة' };
  }

  // ===== الحالة من MyFatoorah مباشرة =====
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let data: any;
  try {
    const res = await fetch(`${base}/v3/payments/${encodeURIComponent(mfPaymentId)}`, {
      headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
    });
    const json = await res.json().catch(() => null);
    if (!res.ok || !json?.IsSuccess || !json?.Data) {
      return { ok: false, paid: false, message: 'تعذّر التحقق من حالة الدفع' };
    }
    data = json.Data;
  } catch {
    return { ok: false, paid: false, message: 'تعذّر الاتصال بـ MyFatoorah' };
  }

  // ===== إيجاد الدفعة =====
  const invoiceId = String(data.Invoice?.Id ?? '');
  const externalId = String(data.Invoice?.ExternalIdentifier ?? '');
  const customerRef = String(data.Customer?.Reference ?? '');

  let payment: { id: string; status: string; total_amount: number; payment_type: string } | null = null;
  if (invoiceId) {
    const { data: p } = await supabase
      .from('payments')
      .select('id, status, total_amount, payment_type')
      .eq('myratoorah_order_id', invoiceId)
      .maybeSingle();
    payment = p;
  }
  if (!payment && UUID_RE.test(externalId)) {
    const { data: p } = await supabase
      .from('payments')
      .select('id, status, total_amount, payment_type')
      .eq('id', externalId)
      .maybeSingle();
    payment = p;
  }
  // الدفع المدمج: رقم الفاتورة غير معروف مسبقاً
  for (const ref of [customerRef, hintRowId ?? '']) {
    if (payment || !UUID_RE.test(ref)) continue;
    const { data: p } = await supabase
      .from('payments')
      .select('id, status, total_amount, payment_type')
      .eq('id', ref)
      .eq('status', 'processing')
      .is('myratoorah_order_id', null)
      .maybeSingle();
    payment = p;
  }
  if (!payment) return { ok: false, paid: false, message: 'لم يتم العثور على الدفعة' };

  // المبلغ المدفوع يجب أن يطابق مبلغ الدفعة
  const paidValue = Number(data.Amount?.ValueInDisplayCurrency ?? data.Amount?.ValueInBaseCurrency);
  if (Number.isFinite(paidValue) && data.Amount?.DisplayCurrency === 'SAR'
      && Math.abs(paidValue - Number(payment.total_amount)) > 0.01) {
    return { ok: false, paid: false, message: 'المبلغ المدفوع لا يطابق الدفعة' };
  }

  const total = Number(payment.total_amount);
  const paid = data.Invoice?.Status === 'PAID';

  // إضافة الرصيد (آمنة للتكرار: الدالة تتجاهل الدفعة إذا أُضيفت مسبقاً)
  const creditWallet = async (): Promise<boolean> => {
    if (payment!.payment_type !== 'wallet_charge') return true;
    const { data: r, error } = await supabase.rpc('credit_wallet_from_payment', {
      p_payment_id: payment!.id,
    });
    return !error && r?.ok === true;
  };

  if (payment.status === 'completed') {
    const credited = await creditWallet();
    return {
      ok: credited,
      paid: true,
      message: credited ? 'تم تسجيل هذه الدفعة مسبقاً' : 'تم الدفع، وجاري إضافة الرصيد',
      paymentRowId: payment.id,
      total,
    };
  }

  const newStatus = paid ? 'completed' : 'failed';
  const failureReason = paid
    ? null
    : data.Transaction?.Error?.Message || data.Invoice?.Status || 'لم يكتمل الدفع';

  // تحديث مشروط: لا يلمس دفعة أصبحت مكتملة في نفس اللحظة (callback و webhook معاً)
  const { data: updated } = await supabase
    .from('payments')
    .update({
      status: newStatus,
      myratoorah_payment_id: data.Transaction?.PaymentId ?? mfPaymentId,
      ...(invoiceId ? { myratoorah_order_id: invoiceId } : {}),
      payment_method: data.Transaction?.PaymentMethod ?? null,
      failure_reason: failureReason,
      ...(paid ? { completed_at: new Date().toISOString() } : {}),
    })
    .eq('id', payment.id)
    .neq('status', 'completed')
    .select('id');

  if (updated && updated.length > 0) {
    await supabase.from('payment_history').insert({
      payment_id: payment.id,
      previous_status: payment.status,
      new_status: newStatus,
      description: `${source === 'webhook' ? 'Webhook' : 'Callback'}: ${
        paid ? 'دفع ناجح عبر MyFatoorah' : `فشل الدفع: ${failureReason}`
      }`,
      myratoorah_response: data,
    });
  }

  if (!paid) {
    return { ok: true, paid: false, message: String(failureReason), paymentRowId: payment.id, total };
  }

  const credited = await creditWallet();
  return {
    ok: credited,
    paid: true,
    message: credited
      ? payment.payment_type === 'wallet_charge'
        ? 'تمت إضافة المبلغ إلى رصيدك'
        : 'شكراً لك، تم استلام المبلغ'
      : 'تم الدفع، وجاري إضافة الرصيد',
    paymentRowId: payment.id,
    total,
  };
}
