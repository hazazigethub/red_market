// site/src/pages/api/payments/checkout.ts
// صفحة الدفع داخل النافذة المنبثقة في اللوحة.
// حقول البطاقة مدمجة من MyFatoorah، ورمز التحقق يظهر داخلها، ولا انتقال لأي موقع آخر.
// تبلغ اللوحة بالنتيجة عبر postMessage.
import type { NextApiRequest, NextApiResponse } from 'next';
import { mfConfig, supabaseAdmin } from '../../../lib/myfatoorah';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function esc(s: string) {
  return s.replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string,
  );
}

function sessionJsUrl(base: string) {
  if (process.env.MYFATOORAH_SESSION_JS) return process.env.MYFATOORAH_SESSION_JS;
  return base.includes('apitest')
    ? 'https://demo.myfatoorah.com/sessions/v1/session.js'
    : 'https://sa.myfatoorah.com/sessions/v1/session.js';
}

const STYLE = `
  *{box-sizing:border-box}
  html,body{margin:0;background:#fff;font-family:'Cairo',Tahoma,Arial,sans-serif;color:#1F2937}
  .wrap{padding:16px}
  .sum{display:flex;justify-content:space-between;align-items:center;background:#F7F8FA;border:1px solid #EDEFF3;border-radius:12px;padding:12px 14px;margin-bottom:14px}
  .sum .lbl{color:#757575;font-size:12.5px}
  .sum .store{font-weight:700;font-size:13.5px}
  .sum .amt{font-size:20px;font-weight:700;color:#D32027;white-space:nowrap}
  #embedded-sessions{min-height:300px}
  .secure{text-align:center;color:#757575;font-size:11.5px;margin-top:10px}
  .state{display:none;text-align:center;padding:40px 10px}
  .state .ic{width:60px;height:60px;border-radius:50%;margin:0 auto 14px;display:flex;align-items:center;justify-content:center;font-size:30px;color:#fff}
  .state h2{font-size:16px;margin:0 0 6px}
  .state p{color:#757575;font-size:13px;margin:0 0 18px}
  .btn{height:44px;padding:0 26px;border:none;border-radius:11px;background:#D32027;color:#fff;font-family:inherit;font-size:14px;font-weight:700;cursor:pointer}
  #st-otp{position:fixed;inset:0;background:#fff;display:none;z-index:10}
  #st-otp iframe{width:100%;height:100%;border:0;display:block}
  .spin{width:36px;height:36px;border:3px solid #EDEFF3;border-top-color:#D32027;border-radius:50%;margin:0 auto 14px;animation:s 1s linear infinite}
  @keyframes s{to{transform:rotate(360deg)}}`;

function page(res: NextApiResponse, body: string, script = '') {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(`<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>الدفع — رد ماركت</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap" rel="stylesheet">
<style>${STYLE}</style>
</head>
<body>${body}${script}</body>
</html>`);
}

/** حالة نهائية بدون نموذج (رابط غير صالح/منتهي) — مع إبلاغ اللوحة */
function notice(res: NextApiResponse, text: string) {
  return page(
    res,
    `<div class="wrap"><div class="state" style="display:block">
       <div class="ic" style="background:#D32027">!</div>
       <h2>تعذّر فتح الدفع</h2><p>${esc(text)}</p>
       <button class="btn" onclick="parent.postMessage({type:'rm-payment',status:'retry'},'*')">المحاولة مرة أخرى</button>
     </div></div>`,
  );
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const pid = typeof req.query.pid === 'string' ? req.query.pid : '';
  if (!UUID_RE.test(pid)) return notice(res, 'رابط الدفع غير صالح');

  const supabase = supabaseAdmin();
  const { base } = mfConfig();
  if (!supabase || !base) return notice(res, 'الدفع غير متاح حالياً');

  const { data: payment } = await supabase
    .from('payments')
    .select('id, status, total_amount, myratoorah_session_id, merchant_id')
    .eq('id', pid)
    .maybeSingle();

  if (!payment) return notice(res, 'الدفعة غير موجودة');
  if (payment.status === 'completed') return notice(res, 'تم دفع هذا المبلغ مسبقاً');
  if (payment.status !== 'processing' || !payment.myratoorah_session_id) {
    return notice(res, 'انتهت صلاحية جلسة الدفع');
  }

  const { data: merchant } = await supabase
    .from('merchants')
    .select('store_name')
    .eq('id', payment.merchant_id)
    .maybeSingle();

  const total = Number(payment.total_amount).toFixed(2);

  const body = `
  <div class="wrap">
    <div id="form">
      <div class="sum">
        <div><div class="lbl">شحن رصيد</div><div class="store">${esc(merchant?.store_name ?? '')}</div></div>
        <div class="amt">${total} ر.س</div>
      </div>
      <div id="embedded-sessions"></div>
      <div class="secure">🔒 بيانات بطاقتك مشفّرة ولا تُحفظ</div>
    </div>

    <div id="st-otp"><iframe id="otp-frame" title="التحقق من البطاقة"></iframe></div>

    <div id="st-wait" class="state"><div class="spin"></div><h2>جارٍ تأكيد الدفع...</h2><p>لا تغلق النافذة</p></div>

    <div id="st-ok" class="state">
      <div class="ic" style="background:#4CAF50">&#10003;</div>
      <h2>تم الدفع بنجاح</h2><p id="ok-msg">أُضيف ${total} ر.س إلى رصيدك</p>
    </div>

    <div id="st-fail" class="state">
      <div class="ic" style="background:#D32027">&#10005;</div>
      <h2>لم يكتمل الدفع</h2><p id="fail-msg">لم يُخصم أي مبلغ</p>
      <button class="btn" onclick="tell('retry')">المحاولة مرة أخرى</button>
    </div>
  </div>`;

  const script = `
  <script src="${esc(sessionJsUrl(base))}"></script>
  <script>
    var PID = ${JSON.stringify(pid)};
    function tell(status, message) {
      parent.postMessage({ type: 'rm-payment', status: status, message: message || '' }, '*');
    }
    function view(id) {
      ['form', 'st-otp', 'st-wait', 'st-ok', 'st-fail'].forEach(function (x) {
        document.getElementById(x).style.display = (x === id) ? 'block' : 'none';
      });
      if (id !== 'st-otp') document.getElementById('otp-frame').src = 'about:blank';
    }
    function fail(text) {
      if (text) document.getElementById('fail-msg').textContent = text;
      view('st-fail');
      tell('failed', text);
    }

    var currentPaymentId = '';

    function idFrom(url) {
      try { return new URL(url).searchParams.get('paymentId') || ''; } catch (e) { return ''; }
    }

    function confirmPayment(id) {
      view('st-wait');
      fetch('/api/payments/confirm?paymentId=' + encodeURIComponent(id) + '&pid=' + encodeURIComponent(PID))
        .then(function (x) { return x.json(); })
        .then(function (d) {
          if (d && d.paid) {
            view('st-ok');
            setTimeout(function () { tell('success'); }, 1400);
          } else {
            fail((d && d.message) || 'رُفضت العملية من البنك');
          }
        })
        .catch(function () { fail('تعذّر تأكيد الدفع — إن خُصم المبلغ سيُضاف لرصيدك تلقائياً'); });
    }

    // بعد إدخال البيانات: نعرض صفحة رمز التحقق بأنفسنا داخل النافذة بكامل مساحتها
    function payment(r) {
      if (!r || !r.isSuccess) return fail('تحقّق من بيانات البطاقة وحاول مرة أخرى');
      if (r.paymentType && r.paymentType !== 'CARD') return fail('طريقة الدفع غير متاحة');

      currentPaymentId = r.paymentId || idFrom(r.redirectionUrl);

      if (r.paymentCompleted && currentPaymentId) return confirmPayment(currentPaymentId);

      if (r.redirectionUrl) {
        document.getElementById('otp-frame').src = r.redirectionUrl;
        view('st-otp');
        return;
      }
      fail('لم يكتمل التحقق من البطاقة');
    }

    // MyFatoorah تبلغنا بانتهاء رمز التحقق برسالة من "MF-3DSecure"
    window.addEventListener('message', function (event) {
      if (!event.data) return;
      var m;
      try { m = typeof event.data === 'string' ? JSON.parse(event.data) : event.data; } catch (e) { return; }
      if (!m || m.sender !== 'MF-3DSecure') return;
      var id = currentPaymentId || idFrom(m.url);
      if (!id) return fail('لم يكتمل التحقق من البطاقة');
      confirmPayment(id);
    }, false);

    try {
      myfatoorah.init({
        sessionId: ${JSON.stringify(String(payment.myratoorah_session_id))},
        containerId: 'embedded-sessions',
        callback: payment,
        shouldHandlePaymentUrl: false
      });
    } catch (e) {
      fail('تعذّر تحميل نموذج الدفع');
    }
  </script>`;

  return page(res, body, script);
}
