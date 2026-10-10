// site/src/pages/api/payments/create.ts
// ينشئ دفعة في Supabase ثم جلسة دفع في MyFatoorah (v3) ويعيد رابط الدفع.
// المفتاح السري لـ MyFatoorah ومفتاح Supabase السري موجودان هنا فقط (على الخادم).
import type { NextApiRequest, NextApiResponse } from 'next';
import { createClient } from '@supabase/supabase-js';

function applyCors(req: NextApiRequest, res: NextApiResponse): boolean {
  const origin = req.headers.origin ?? '';
  const allowed = (process.env.PANEL_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const isDevLocal =
    process.env.NODE_ENV !== 'production' &&
    origin.startsWith('http://localhost:');

  if (origin && (isDevLocal || allowed.includes(origin))) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return true;
  }
  return false;
}

const round2 = (n: number) => Math.round(n * 100) / 100;

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (applyCors(req, res)) return;
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const mfBase = (process.env.MYFATOORAH_BASE_URL ?? '').replace(/\/+$/, '');
  const mfKey = process.env.MYFATOORAH_API_KEY ?? '';
  const siteUrl = (process.env.SITE_URL ?? '').replace(/\/+$/, '');
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';

  if (!mfBase || !mfKey || !siteUrl || !supabaseUrl || !serviceKey) {
    return res.status(500).json({ error: 'الشحن غير متاح حالياً' });
  }

  // ===== التحقق من المستخدم عبر جلسة Supabase =====
  const token = (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'يجب تسجيل الدخول' });

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData?.user) {
    return res.status(401).json({ error: 'جلسة غير صالحة، سجّل الدخول من جديد' });
  }

  // payments.merchant_id يشير إلى merchants.id (وليس معرّف المستخدم)
  const { data: merchant, error: merchantError } = await supabase
    .from('merchants')
    .select('id')
    .eq('owner_id', userData.user.id)
    .maybeSingle();

  if (merchantError) {
    return res.status(500).json({ error: `خطأ قراءة المتجر: ${merchantError.message}` });
  }
  if (!merchant) {
    return res.status(403).json({ error: 'لا يوجد متجر مرتبط بهذا الحساب' });
  }

  // ===== المبلغ =====
  // الدفع حالياً لشحن المحفظة فقط. الضريبة تُحسب عند الشراء من الرصيد
  // (purchase_banner / purchase_splash_ad)، فلا تُضاف هنا حتى لا تتكرر.
  const body = (req.body ?? {}) as Record<string, unknown>;
  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount < 10 || amount > 50000) {
    return res.status(400).json({ error: 'مبلغ الشحن يجب أن يكون بين 10 و 50,000 ر.س' });
  }
  const paymentType = 'wallet_charge';
  const referenceId = null;

  const base = round2(amount);
  const vat = 0;
  const total = base;

  // ===== سجل الدفعة =====
  const { data: payment, error: insertError } = await supabase
    .from('payments')
    .insert({
      merchant_id: merchant.id,
      amount: base,
      vat_amount: vat,
      total_amount: total,
      currency: 'SAR',
      payment_type: paymentType,
      reference_id: referenceId,
      status: 'pending',
    })
    .select('id')
    .single();

  if (insertError || !payment) {
    return res.status(500).json({ error: `فشل حفظ الدفعة: ${insertError?.message ?? ''}` });
  }

  const markFailed = (reason: string) =>
    supabase
      .from('payments')
      .update({ status: 'failed', failure_reason: reason })
      .eq('id', payment.id);

  // ===== جلسة دفع مدمجة في MyFatoorah (POST /v3/sessions) =====
  // العميل يدفع داخل صفحة رد ماركت (checkout) ولا يرى موقع MyFatoorah
  try {
    const integrationUrls = siteUrl.startsWith('https://')
      ? {
          IntegrationUrls: {
            Redirection: `${siteUrl}/api/payments/callback`,
            Webhook: `${siteUrl}/api/webhooks/payment`,
          },
        }
      : {};

    const mfRes = await fetch(`${mfBase}/v3/sessions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${mfKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        PaymentMode: 'COMPLETE_PAYMENT',
        Order: { Amount: total, Currency: 'SAR', ExternalIdentifier: payment.id },
        // لا نرسل مرجع عميل: لا ربط للبطاقات بالحساب ولا حفظ لها
        // البطاقات فقط: الطرق غير المدعومة في الدمج تحوّل العميل لصفحة MyFatoorah
        SupportedPaymentMethods: ['card'],
        ...integrationUrls,
        Language: 'AR',
      }),
    });

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const mfJson: any = await mfRes.json().catch(() => null);

    if (!mfRes.ok || !mfJson?.IsSuccess || !mfJson?.Data?.SessionId) {
      const reason =
        (Array.isArray(mfJson?.ValidationErrors) &&
          mfJson.ValidationErrors
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            .map((e: any) => `${e.Name}: ${e.Error}`)
            .join(' | ')) ||
        mfJson?.Message ||
        `HTTP ${mfRes.status}`;
      await markFailed(reason);
      return res.status(502).json({ error: `تعذّر إنشاء الدفع: ${reason}` });
    }

    await supabase
      .from('payments')
      .update({
        status: 'processing',
        myratoorah_session_id: String(mfJson.Data.SessionId),
      })
      .eq('id', payment.id);

    return res.status(200).json({
      payment_id: payment.id,
      payment_url: `${siteUrl}/api/payments/checkout?pid=${payment.id}`,
    });
  } catch (e) {
    const reason = e instanceof Error ? e.message : String(e);
    await markFailed(reason);
    return res.status(502).json({ error: `تعذّر الاتصال بـ MyFatoorah: ${reason}` });
  }
}
