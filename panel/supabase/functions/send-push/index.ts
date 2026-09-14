// ===== إرسال الإشعارات المنبثقة عبر Firebase Cloud Messaging =====
// يُستدعى من قاعدة البيانات أو من لوحة الأدمن

import { createClient } from 'jsr:@supabase/supabase-js@2';

const FIREBASE_PROJECT_ID = 'red-market-f7c99';
const CLIENT_EMAIL =
  'firebase-adminsdk-fbsvc@red-market-f7c99.iam.gserviceaccount.com';

/** يبني رمز وصول من مفتاح الخدمة */
async function getAccessToken(): Promise<string> {
  const privateKey = (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replace(
    /\\n/g,
    '\n',
  );

  if (!privateKey) throw new Error('FIREBASE_PRIVATE_KEY غير مضبوط');

  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

  const unsigned = `${enc(header)}.${enc(payload)}`;

  // استيراد المفتاح الخاص
  const pem = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');

  const binary = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    binary,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  const jwt = `${unsigned}.${sig}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!data.access_token) {
    throw new Error(`فشل الحصول على رمز الوصول: ${JSON.stringify(data)}`);
  }

  return data.access_token as string;
}

/** يرسل إشعاراً واحداً لجهاز */
async function sendToDevice(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: 'high',
            notification: {
              channel_id: 'red_market_channel',
              sound: 'default',
            },
          },
        },
      }),
    },
  );

  if (!res.ok) {
    const err = await res.text();
    console.error(`فشل الإرسال للرمز ${token.slice(0, 12)}...: ${err}`);
    return false;
  }

  return true;
}

Deno.serve(async (req) => {
  // ترويسات CORS
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  try {
    const payload = await req.json();

    const title: string = payload.title ?? 'رد ماركت';
    const body: string = payload.body ?? '';
    const userIds: string[] | null = payload.user_ids ?? null;
    const extra: Record<string, string> = payload.data ?? {};

    if (!body) {
      return new Response(
        JSON.stringify({ ok: false, error: 'نص الإشعار مطلوب' }),
        { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // جلب رموز الأجهزة
    let query = supabase
      .from('device_tokens')
      .select('token')
      .eq('is_active', true);

    if (userIds && userIds.length > 0) {
      query = query.in('user_id', userIds);
    }

    const { data: rows, error } = await query;

    if (error) {
      return new Response(
        JSON.stringify({ ok: false, error: error.message }),
        { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
      );
    }

    const tokens = (rows ?? []).map((r) => r.token as string);

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, sent: 0, note: 'لا أجهزة مسجّلة' }),
        { headers: { ...cors, 'Content-Type': 'application/json' } },
      );
    }

    const accessToken = await getAccessToken();

    let sent = 0;
    for (const token of tokens) {
      const ok = await sendToDevice(accessToken, token, title, body, extra);
      if (ok) sent++;
    }

    return new Response(
      JSON.stringify({ ok: true, sent, total: tokens.length }),
      { headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('send-push error:', e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }
});
