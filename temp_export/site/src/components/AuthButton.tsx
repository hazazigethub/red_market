'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabaseBrowser } from '@/lib/supabase-client';
import type { User } from '@supabase/supabase-js';

export default function AuthButton() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    supabaseBrowser.auth.getUser().then(({ data }) => {
      setUser(data.user);
      setReady(true);
    });

    const { data: sub } = supabaseBrowser.auth.onAuthStateChange(
      (_event, session) => {
        setUser(session?.user ?? null);
      }
    );

    return () => sub.subscription.unsubscribe();
  }, []);

  async function handleLogout() {
    await supabaseBrowser.auth.signOut();
    router.push('/');
    router.refresh();
  }

  if (!ready) {
    return <span className="w-16 h-4" aria-hidden />;
  }

  if (!user) {
    return (
      <Link href="/login" className="hover:text-red-700">
        دخول
      </Link>
    );
  }

  return (
    <div className="flex items-center gap-4">
      <Link href="/account" className="hover:text-red-700">
        حسابي
      </Link>
      <button
        onClick={handleLogout}
        className="text-gray-500 hover:text-red-700 text-sm"
      >
        خروج
      </button>
    </div>
  );
}