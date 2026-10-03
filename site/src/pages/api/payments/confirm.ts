// site/src/pages/api/payments/confirm.ts
// تستدعيه صفحة الدفع المدمجة بعد إتمام رمز التحقق: يتأكد من MyFatoorah ويحدّث الرصيد
import type { NextApiRequest, NextApiResponse } from 'next';
import { syncPayment } from '../../../lib/myfatoorah';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  res.setHeader('Cache-Control', 'no-store');
  const paymentId = typeof req.query.paymentId === 'string' ? req.query.paymentId : '';
  const pid = typeof req.query.pid === 'string' ? req.query.pid : undefined;
  if (!paymentId) return res.status(400).json({ paid: false, message: 'طلب غير صالح' });

  const r = await syncPayment(paymentId, 'callback', pid);
  return res.status(200).json({ paid: r.paid, message: r.message });
}
