// site/pages/api/webhooks/payment.ts
import { NextApiRequest, NextApiResponse } from 'next';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// ============================================================
// Webhook Handler لـ Myratoorah Payment Events
// ============================================================

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const payload = req.body;
    const signature = req.headers['x-myratoorah-signature'] as string;

    // ✅ التحقق من توقيع الـ Webhook (اختياري - يمكن تفعيله لاحقاً)
    // if (!verifyWebhookSignature(JSON.stringify(payload), signature)) {
    //   return res.status(401).json({ error: 'Invalid signature' });
    // }

    console.log('📨 استقبال webhook:', payload);

    const eventType = payload.event_type || payload.type;
    const paymentId = payload.payment_id || payload.id;

    // ============================================================
    // 1️⃣ تسجيل الـ Webhook
    // ============================================================

    const webhookRecord = await supabase.from('payment_webhooks').insert({
      webhook_id: payload.webhook_id || `wh_${Date.now()}`,
      event_type: eventType,
      payload: payload,
      status: 'pending',
      received_at: new Date().toISOString(),
    });

    // ============================================================
    // 2️⃣ معالجة الأحداث المختلفة
    // ============================================================

    switch (eventType) {
      case 'payment.completed':
      case 'payment.success':
        await handlePaymentCompleted(paymentId, payload);
        break;

      case 'payment.failed':
        await handlePaymentFailed(paymentId, payload);
        break;

      case 'payment.cancelled':
        await handlePaymentCancelled(paymentId, payload);
        break;

      case 'refund.completed':
      case 'refund.processed':
        await handleRefundCompleted(paymentId, payload);
        break;

      case 'refund.failed':
        await handleRefundFailed(paymentId, payload);
        break;

      default:
        console.log('⚠️ حدث غير معروف:', eventType);
    }

    // ============================================================
    // 3️⃣ تحديث حالة الـ Webhook
    // ============================================================

    await supabase
      .from('payment_webhooks')
      .update({
        status: 'processed',
        processed_at: new Date().toISOString(),
      })
      .eq('webhook_id', payload.webhook_id || `wh_${Date.now()}`);

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('❌ خطأ معالجة الـ Webhook:', error);

    // سجّل الخطأ
    await supabase.from('payment_webhooks').update({
      status: 'failed',
      error_message: String(error),
      processed_at: new Date().toISOString(),
    });

    return res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================
// معالجات الأحداث
// ============================================================

async function handlePaymentCompleted(
  paymentId: string,
  payload: any
) {
  console.log('✅ دفعة مكتملة:', paymentId);

  // 🔍 احصل على بيانات الدفعة
  const paymentData = await supabase
    .from('payments')
    .select('*')
    .eq('myratoorah_payment_id', paymentId)
    .maybeSingle();

  if (!paymentData.data) {
    console.warn('⚠️ دفعة غير موجودة:', paymentId);
    return;
  }

  const payment = paymentData.data;

  // 📝 حدّث حالة الدفعة
  await supabase
    .from('payments')
    .update({
      status: 'completed',
      myratoorah_payment_id: paymentId,
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', payment.id);

  // 📝 سجّل في سجل المدفوعات
  await supabase.from('payment_history').insert({
    payment_id: payment.id,
    previous_status: 'processing',
    new_status: 'completed',
    description: 'دفعة مكتملة بنجاح',
    myratoorah_response: payload,
  });

  // ✅ حدّث المحفظة
  if (payment.payment_type === 'subscription') {
    await activateSubscription(payment.merchant_id, payment.subscription_id);
  } else if (payment.payment_type === 'banner_booking') {
    await approveBannerBooking(payment.booking_id);
  }

  // 📨 أرسل إشعار للتاجر
  await sendPaymentNotification(payment.merchant_id, 'success', payment);
}

async function handlePaymentFailed(
  paymentId: string,
  payload: any
) {
  console.log('❌ دفعة فاشلة:', paymentId);

  const paymentData = await supabase
    .from('payments')
    .select('*')
    .eq('myratoorah_payment_id', paymentId)
    .maybeSingle();

  if (!paymentData.data) return;

  const payment = paymentData.data;

  // حدّث الحالة
  await supabase
    .from('payments')
    .update({
      status: 'failed',
      failure_reason: payload.error_message || 'Payment failed',
      updated_at: new Date().toISOString(),
    })
    .eq('id', payment.id);

  // سجّل في السجل
  await supabase.from('payment_history').insert({
    payment_id: payment.id,
    previous_status: 'processing',
    new_status: 'failed',
    description: payload.error_message || 'فشل الدفع',
    myratoorah_response: payload,
  });

  // أرسل إشعار
  await sendPaymentNotification(payment.merchant_id, 'failed', payment);
}

async function handlePaymentCancelled(
  paymentId: string,
  payload: any
) {
  console.log('🚫 دفعة ملغاة:', paymentId);

  const paymentData = await supabase
    .from('payments')
    .select('*')
    .eq('myratoorah_payment_id', paymentId)
    .maybeSingle();

  if (!paymentData.data) return;

  const payment = paymentData.data;

  await supabase
    .from('payments')
    .update({
      status: 'cancelled',
      updated_at: new Date().toISOString(),
    })
    .eq('id', payment.id);

  await sendPaymentNotification(payment.merchant_id, 'cancelled', payment);
}

async function handleRefundCompleted(
  paymentId: string,
  payload: any
) {
  console.log('💰 استرجاع مكتمل:', paymentId);

  const refundId = payload.refund_id || payload.id;

  // ابحث عن طلب الاسترجاع
  const refundRequest = await supabase
    .from('refund_requests')
    .select('*')
    .eq('myratoorah_refund_id', refundId)
    .maybeSingle();

  if (refundRequest.data) {
    await supabase
      .from('refund_requests')
      .update({
        status: 'completed',
        refund_date: new Date().toISOString(),
      })
      .eq('id', refundRequest.data.id);

    // حدّث المحفظة
    const wallet = await supabase
      .from('merchant_wallets')
      .select('*')
      .eq('merchant_id', refundRequest.data.merchant_id)
      .maybeSingle();

    if (wallet.data) {
      const newBalance = (wallet.data.balance || 0) + refundRequest.data.amount;
      await supabase
        .from('merchant_wallets')
        .update({ balance: newBalance })
        .eq('merchant_id', refundRequest.data.merchant_id);
    }
  }
}

async function handleRefundFailed(
  paymentId: string,
  payload: any
) {
  console.log('❌ استرجاع فاشل:', paymentId);

  const refundId = payload.refund_id || payload.id;

  const refundRequest = await supabase
    .from('refund_requests')
    .select('*')
    .eq('myratoorah_refund_id', refundId)
    .maybeSingle();

  if (refundRequest.data) {
    await supabase
      .from('refund_requests')
      .update({
        status: 'failed',
        admin_note: payload.error_message || 'Refund failed',
      })
      .eq('id', refundRequest.data.id);
  }
}

// ============================================================
// دوال مساعدة
// ============================================================

async function activateSubscription(
  merchantId: string,
  subscriptionId: string
) {
  console.log('🎯 تفعيل الاشتراك:', subscriptionId);

  // احصل على بيانات الاشتراك
  const subscription = await supabase
    .from('merchant_subscriptions')
    .select('*')
    .eq('id', subscriptionId)
    .maybeSingle();

  if (!subscription.data) return;

  // احسب تواريخ انتهاء الاشتراك
  const startDate = new Date();
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + subscription.data.duration_days || 30);

  // حدّث الاشتراك
  await supabase
    .from('merchant_subscriptions')
    .update({
      status: 'active',
      started_at: startDate.toISOString(),
      expires_at: endDate.toISOString(),
    })
    .eq('id', subscriptionId);

  // حدّث ملف التاجر
  await supabase
    .from('profiles')
    .update({
      is_subscription_active: true,
      subscription_start_date: startDate.toISOString(),
      subscription_end_date: endDate.toISOString(),
    })
    .eq('id', merchantId);
}

async function approveBannerBooking(bookingId: string) {
  console.log('📢 الموافقة على حجز البنر:', bookingId);

  await supabase
    .from('banner_bookings')
    .update({
      status: 'approved',
      is_approved: true,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', bookingId);
}

async function sendPaymentNotification(
  merchantId: string,
  status: 'success' | 'failed' | 'cancelled',
  payment: any
) {
  const messages: Record<string, string> = {
    success: `✅ تم استقبال دفعتك بقيمة ${payment.total_amount} ر.س`,
    failed: '❌ فشلت عملية الدفع. يرجى المحاولة مرة أخرى',
    cancelled: '🚫 تم إلغاء عملية الدفع',
  };

  console.log(`📬 إرسال إشعار للتاجر ${merchantId}:`, messages[status]);

  // يمكن إضافة نظام إشعارات هنا (Firebase, Email, SMS)
}

// ============================================================
// التحقق من التوقيع (اختياري)
// ============================================================

function verifyWebhookSignature(
  payload: string,
  signature: string
): boolean {
  // TODO: تطبيق HMAC-SHA256 verification
  // استخدم المفتاح السري من Myratoorah
  return true;
}
