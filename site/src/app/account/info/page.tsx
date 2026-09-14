'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabaseBrowser } from '@/lib/supabase-client';

const BRAND = '#D32027';

type Cat = { id: string; name: string | null };

export default function AccountPage() {
  const router = useRouter();

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');

  const [cats, setCats] = useState<Cat[]>([]);
  const [selected, setSelected] = useState<string[]>([]);

  const [ready, setReady] = useState(false);
  const [savingInfo, setSavingInfo] = useState(false);
  const [savingCats, setSavingCats] = useState(false);
  const [msgInfo, setMsgInfo] = useState<{ t: string; ok: boolean } | null>(null);
  const [msgCats, setMsgCats] = useState<{ t: string; ok: boolean } | null>(null);

  // حذف الحساب
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [msgDelete, setMsgDelete] = useState<{ t: string; ok: boolean } | null>(
    null
  );

  useEffect(() => {
    async function load() {
      const { data } = await supabaseBrowser.auth.getUser();
      const u = data.user;
      if (!u) {
        router.replace('/login');
        return;
      }
      setEmail(u.email ?? '');

      const [profRes, catRes] = await Promise.all([
        supabaseBrowser
          .from('profiles')
          .select('full_name, name, phone_number, preferred_categories')
          .eq('id', u.id)
          .maybeSingle(),
        supabaseBrowser
          .from('store_categories')
          .select('id, name')
          .eq('is_visible', true)
          .order('name'),
      ]);

      const p = profRes.data;
      setName(p?.full_name || p?.name || '');
      setPhone(p?.phone_number || '');
      setSelected((p?.preferred_categories as string[]) ?? []);
      setCats((catRes.data as Cat[]) ?? []);
      setReady(true);
    }
    load();
  }, [router]);

  async function saveInfo(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) {
      setMsgInfo({ t: 'الاسم لا يمكن أن يكون فارغاً', ok: false });
      return;
    }
    setSavingInfo(true);
    setMsgInfo(null);
    try {
      const { data } = await supabaseBrowser.auth.getUser();
      const u = data.user;
      if (!u) return;

      await supabaseBrowser.auth.updateUser({
        data: { full_name: name.trim() },
      });

      await supabaseBrowser
        .from('profiles')
        .update({ full_name: name.trim(), name: name.trim() })
        .eq('id', u.id);

      setMsgInfo({ t: 'تم تحديث بياناتك بنجاح', ok: true });
    } catch {
      setMsgInfo({ t: 'تعذر الحفظ، حاول مجدداً', ok: false });
    } finally {
      setSavingInfo(false);
    }
  }

  function toggleCat(id: string) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    );
  }

  async function saveCats() {
    setSavingCats(true);
    setMsgCats(null);
    try {
      const { data } = await supabaseBrowser.auth.getUser();
      const u = data.user;
      if (!u) return;

      const { error } = await supabaseBrowser
        .from('profiles')
        .update({ preferred_categories: selected })
        .eq('id', u.id);

      if (error) {
        setMsgCats({ t: 'تعذر الحفظ، حاول مجدداً', ok: false });
        return;
      }
      setMsgCats({ t: 'تم حفظ اهتماماتك', ok: true });
    } catch {
      setMsgCats({ t: 'تعذر الاتصال', ok: false });
    } finally {
      setSavingCats(false);
    }
  }

  async function requestDeletion() {
    if (deleting) return;
    setDeleting(true);
    setMsgDelete(null);

    try {
      const { data, error } = await supabaseBrowser.rpc(
        'request_account_deletion'
      );

      if (error) {
        setMsgDelete({ t: 'تعذر إرسال الطلب، حاول مجدداً', ok: false });
        return;
      }

      const res = data as { ok?: boolean; error?: string } | null;

      if (res?.ok) {
        setMsgDelete({
          t: 'تم استلام طلبك. سيُحذف حسابك بعد 30 يوماً، ويمكنك التراجع بالدخول خلال هذه المدة.',
          ok: true,
        });
        setConfirmDelete(false);

        setTimeout(async () => {
          await supabaseBrowser.auth.signOut();
          router.push('/');
          router.refresh();
        }, 3000);
      } else {
        setMsgDelete({
          t: res?.error ?? 'تعذر إرسال الطلب',
          ok: false,
        });
      }
    } catch {
      setMsgDelete({ t: 'تعذر الاتصال، تحقق من الشبكة', ok: false });
    } finally {
      setDeleting(false);
    }
  }

  if (!ready) {
    return (
      <main className="max-w-2xl mx-auto px-4 py-16">
        <p className="text-center text-gray-500">جاري التحميل...</p>
      </main>
    );
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-10">
      <h1 className="text-2xl font-bold mb-8">حسابي</h1>

      {/* ===== البيانات الشخصية ===== */}
      <section className="border border-gray-200 rounded-xl p-6">
        <h2 className="font-bold mb-5">المعلومات الشخصية</h2>

        <form onSubmit={saveInfo} className="space-y-4">
          <div>
            <label className="block text-sm mb-1.5 text-gray-700">الاسم</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:border-red-400"
            />
          </div>

          <div>
            <label className="block text-sm mb-1.5 text-gray-700">
              رقم الجوال
            </label>
            <input
              type="text"
              value={phone}
              disabled
              className="w-full border border-gray-200 bg-gray-50 rounded-lg px-4 py-2.5 text-gray-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              لا يمكن تغيير رقم الجوال
            </p>
          </div>

          <button
            type="submit"
            disabled={savingInfo}
            className="w-full text-white font-bold py-3 rounded-lg disabled:opacity-60"
            style={{ backgroundColor: BRAND }}
          >
            {savingInfo ? 'جاري الحفظ...' : 'حفظ البيانات'}
          </button>

          {msgInfo && (
            <p
              className={`text-center text-sm ${
                msgInfo.ok ? 'text-green-600' : 'text-red-600'
              }`}
            >
              {msgInfo.t}
            </p>
          )}
        </form>
      </section>

      {/* ===== الاهتمامات ===== */}
      <section className="border border-gray-200 rounded-xl p-6 mt-6">
        <h2 className="font-bold mb-1.5">الاهتمامات</h2>
        <p className="text-sm text-gray-500 mb-5">
          اختر التصنيفات التي تهمك لنعرض لك ما يناسبك
        </p>

        <div className="flex flex-wrap gap-2">
          {cats.map((c) => {
            const on = selected.includes(c.id);
            return (
              <button
                key={c.id}
                type="button"
                onClick={() => toggleCat(c.id)}
                className={`px-3.5 py-1.5 rounded-lg border text-xs transition-colors ${
                  on
                    ? 'border-red-400 bg-red-50 text-red-700 font-bold'
                    : 'border-gray-200 text-gray-700 hover:border-red-300'
                }`}
              >
                {c.name}
              </button>
            );
          })}
        </div>

        <button
          onClick={saveCats}
          disabled={savingCats}
          className="w-full mt-6 text-white font-bold py-3 rounded-lg disabled:opacity-60"
          style={{ backgroundColor: BRAND }}
        >
          {savingCats ? 'جاري الحفظ...' : 'حفظ الاهتمامات'}
        </button>

        {msgCats && (
          <p
            className={`text-center text-sm mt-3 ${
              msgCats.ok ? 'text-green-600' : 'text-red-600'
            }`}
          >
            {msgCats.t}
          </p>
        )}
      </section>

      {/* ===== حذف الحساب ===== */}
      <section className="border border-red-200 rounded-xl p-6 mt-6">
        <h2 className="font-bold mb-3 text-red-700">حذف الحساب</h2>

        <ul className="text-sm text-gray-700 leading-7 space-y-1.5">
          <li>• يُعطَّل حسابك فور تقديم الطلب</li>
          <li>• تُحذف بياناتك نهائياً بعد 30 يوماً</li>
          <li>• يمكنك التراجع بالدخول خلال هذه المدة</li>
          <li>• بعد الحذف تُفقد مفضلتك ومتابعاتك وتعليقاتك</li>
        </ul>

        {!confirmDelete ? (
          <button
            onClick={() => {
              setConfirmDelete(true);
              setMsgDelete(null);
            }}
            className="mt-5 px-6 py-2.5 rounded-lg border border-red-300 text-red-700 text-sm font-bold hover:bg-red-50 transition-colors"
          >
            طلب حذف الحساب
          </button>
        ) : (
          <div className="mt-5 bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-sm text-red-800 font-bold mb-3">
              هل أنت متأكد؟
            </p>
            <div className="flex flex-wrap gap-3">
              <button
                onClick={requestDeletion}
                disabled={deleting}
                className="px-6 py-2.5 rounded-lg bg-red-600 text-white text-sm font-bold disabled:opacity-60 hover:opacity-90 transition-opacity"
              >
                {deleting ? 'جاري الإرسال...' : 'نعم، احذف حسابي'}
              </button>
              <button
                onClick={() => setConfirmDelete(false)}
                disabled={deleting}
                className="px-6 py-2.5 rounded-lg border border-gray-300 text-gray-700 text-sm font-bold hover:bg-white transition-colors"
              >
                تراجع
              </button>
            </div>
          </div>
        )}

        {msgDelete && (
          <p
            className={`text-sm mt-4 leading-7 ${
              msgDelete.ok ? 'text-green-700' : 'text-red-600'
            }`}
          >
            {msgDelete.t}
          </p>
        )}

        <p className="text-xs text-gray-500 mt-4 leading-6">
          لأي استفسار قبل الحذف،{' '}
          <Link href="/support" className="font-bold underline">
            تواصل مع الدعم
          </Link>
        </p>
      </section>

      <p className="text-center text-xs text-gray-500 mt-8">{email}</p>
    </main>
  );
}
