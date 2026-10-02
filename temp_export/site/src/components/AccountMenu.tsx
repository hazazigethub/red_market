'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { UserCog, LogOut } from 'lucide-react';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { User } from '@supabase/supabase-js';

export default function AccountMenu() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    supabaseBrowser.auth.getUser().then(({ data }) => {
      setUser(data.user);
      setReady(true);
    });

    const { data: sub } = supabaseBrowser.auth.onAuthStateChange(
      (_event, session) => setUser(session?.user ?? null)
    );

    return () => sub.subscription.unsubscribe();
  }, []);

  async function logout() {
    await supabaseBrowser.auth.signOut();
    router.push('/');
    router.refresh();
  }

  if (!ready) {
    return <span className="w-11 h-11" aria-hidden />;
  }

  if (!user) {
    return (
      <Link
        href="/login"
        // 16 - 6 = 10 بكسل من الحافة — مطابق للجرس
        className="text-base font-bold hover:opacity-80 transition-opacity whitespace-nowrap ps-2 -me-[6px]"
        style={{ color: '#D32027' }}
      >
        تسجيل الدخول
      </Link>
    );
  }

  return (
    <div className="flex items-center gap-0 -me-[13px]">
      <Link
        href="/account/info"
        aria-label="حسابي"
        title="حسابي"
        className="w-11 h-11 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors -me-[6px]"
        style={{ color: '#D32027' }}
      >
        <UserCog size={30} strokeWidth={1.6} />
      </Link>

      <button
        onClick={logout}
        aria-label="تسجيل الخروج"
        title="تسجيل الخروج"
        className="w-11 h-11 rounded-full flex items-center justify-center hover:bg-gray-100 transition-colors"
        style={{ color: '#D32027' }}
      >
        <LogOut size={26} strokeWidth={1.8} />
      </button>
    </div>
  );
}
