'use client';

import { useEffect, useState } from 'react';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { User } from '@supabase/supabase-js';

const BRAND = '#D32027';

export default function SupportPage() {
  const [user, setUser] = useState<User | null>(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [msg, setMsg] = useState<{ text: string; ok: boolean } | null>(null);

  useEffect(() => {
    supabaseBrowser.auth.getUser().then(({ data }) => {
      setUser(data.user);
      const meta = data.user?.user_metadata as
        | { full_name?: string }
        | undefined;
      if (meta?.full_name) setName(meta.full_name);
      if (data.user?.phone) setPhone(data.user.phone);
    });
  }, []);

  async function send(e: React.FormEvent) {
    e.preventDefault();

    if (!name.trim() || !subject.trim() || !message.trim()) {
      setMsg({ text: 'يرجى تعبئة الاسم والموضوع وتفاصيل الرسالة', ok: false });
      return;
    }

    if (!phone.trim() && !email.trim()) {
      setMsg({
        text: 'أدخل رقم جوال أو بريداً إلكترونياً لنتمكن من الرد عليك',
        ok: false,
      });
      return;
    }

    setSending(true);
    setMsg(null);

    try {
      const { error } = await supabaseBrowser.from('contact_requests').insert({
        name: name.trim(),
        phone: phone.trim() || null,
        email: email.trim() || null,
        subject: subject.trim(),
        message: message.trim(),
        source: 'website',
        user_id: user?.id ?? null,
        status: 'new',
      });

      if (error) {
        setMsg({ text: 'تعذر إرسال الرسالة، حاول مجدداً', ok: false });
        return;
      }

      setMsg({
        text: 'تم إرسال رسالتك. سنرد عليك خلال 24 ساعة في أيام العمل.',
        ok: true,
      });
      setSubject('');
      setMessage('');
    } catch {
      setMsg({ text: 'تعذر الاتصال، تحقق من الشبكة', ok: false });
    } finally {
      setSending(false);
    }
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-12">
      <h1 className="text-2xl font-bold mb-2">تواصل معنا</h1>
      <p className="text-sm text-gray-500 mb-8">
        سواء كنت عميلاً أو تاجراً، نحن هنا للمساعدة
      </p>

      {/* ===== قنوات التواصل ===== */}
      <div className="grid sm:grid-cols-2 gap-3 mb-8">
        <div className="border border-gray-200 rounded-xl p-4 flex items-center gap-3">
          <div
            className="w-10 h-10 rounded-lg shrink-0 flex items-center justify-center"
            style={{ backgroundColor: `${BRAND}0F` }}
          >
            <svg
              className="w-5 h-5"
              fill="none"
              stroke={BRAND}
              strokeWidth={1.8}
              viewBox="0 0 24 24"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
            </svg>
          </div>
          <div>
            <p className="text-xs text-gray-500">واتساب الدعم</p>
            <p className="text-sm font-bold text-red-600">( رقم الواتساب )</p>
          </div>
        </div>

        <div className="border border-gray-200 rounded-xl p-4 flex items-center gap-3">
          <div
            className="w-10 h-10 rounded-lg shrink-0 flex items-center justify-center"
            style={{ backgroundColor: `${BRAND}0F` }}
          >
            <svg
              className="w-5 h-5"
              fill="none"
              stroke={BRAND}
              strokeWidth={1.8}
              viewBox="0 0 24 24"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
          </div>
          <div>
            <p className="text-xs text-gray-500">البريد الإلكتروني</p>
            <p className="text-sm font-bold text-red-600">
              ( البريد الإلكتروني )
            </p>
          </div>
        </div>
      </div>

      {/* ===== النموذج ===== */}
      <form
        onSubmit={send}
        className="bg-white border border-gray-200 rounded-xl p-6 space-y-4"
      >
        <h2 className="font-bold mb-1">أرسل لنا رسالة</h2>

        <div className="grid sm:grid-cols-2 gap-4">
          <div>
            <label
              htmlFor="sup-name"
              className="block text-sm mb-1.5 text-gray-700"
            >
              الاسم
            </label>
            <input
              id="sup-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="اسمك"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400 text-sm"
            />
          </div>

          <div>
            <label
              htmlFor="sup-phone"
              className="block text-sm mb-1.5 text-gray-700"
            >
              رقم الجوال
            </label>
            <input
              id="sup-phone"
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="05xxxxxxxx"
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400 text-sm"
            />
          </div>
        </div>

        <div>
          <label
            htmlFor="sup-email"
            className="block text-sm mb-1.5 text-gray-700"
          >
            البريد الإلكتروني{' '}
            <span className="text-gray-500 text-xs">(اختياري)</span>
          </label>
          <input
            id="sup-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="name@example.com"
            className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400 text-sm"
          />
        </div>

        <div>
          <label
            htmlFor="sup-subject"
            className="block text-sm mb-1.5 text-gray-700"
          >
            موضوع الرسالة
          </label>
          <input
            id="sup-subject"
            type="text"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            placeholder="مثال: استفسار عن تسجيل متجر"
            className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400 text-sm"
          />
        </div>

        <div>
          <label
            htmlFor="sup-message"
            className="block text-sm mb-1.5 text-gray-700"
          >
            تفاصيل الرسالة
          </label>
          <textarea
            id="sup-message"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            rows={5}
            placeholder="اكتب استفسارك بوضوح"
            className="w-full border border-gray-300 rounded-lg px-4 py-3 outline-none focus:border-red-400 resize-none text-sm"
          />
        </div>

        <button
          type="submit"
          disabled={sending}
          className="w-full text-white font-bold py-3 rounded-lg disabled:opacity-60 hover:opacity-90 transition-opacity"
          style={{ backgroundColor: BRAND }}
        >
          {sending ? 'جاري الإرسال...' : 'إرسال'}
        </button>

        {msg && (
          <p
            className={`text-center text-sm leading-7 ${
              msg.ok ? 'text-green-600' : 'text-red-600'
            }`}
          >
            {msg.text}
          </p>
        )}
      </form>

      <p className="text-center text-xs text-gray-500 mt-6 leading-6">
        نرد على الرسائل خلال 24 ساعة في أيام العمل
      </p>
    </main>
  );
}
