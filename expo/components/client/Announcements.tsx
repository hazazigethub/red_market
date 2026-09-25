"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { realtimeAuth } from "@/components/client/useSession";

/** Organizer announcements + live refresh when a stream starts or ends. */
export function Announcements({ exhibitionId }: { exhibitionId: string }) {
  const router = useRouter();
  const [msg, setMsg] = useState<string | null>(null);
  useEffect(() => {
    let ch: RealtimeChannel | null = null;
    realtimeAuth().then((sb) => {
      ch = sb.channel(`expo:${exhibitionId}`, { config: { private: true } })
        .on("broadcast", { event: "announcement" }, ({ payload }) => setMsg(payload.message))
        .on("broadcast", { event: "stream_status" }, () => router.refresh())
        .subscribe();
    });
    return () => { ch?.unsubscribe(); };
  }, [exhibitionId, router]);
  if (!msg) return null;
  return (
    <div role="status" className="fixed inset-x-3 bottom-3 z-50 mx-auto flex max-w-xl items-start gap-3 rounded-2xl bg-ink p-4 text-bg shadow-2xl">
      <span className="badge-live shrink-0">إعلان</span>
      <p className="flex-1 text-sm">{msg}</p>
      <button className="text-sm opacity-70 hover:opacity-100" onClick={() => setMsg(null)} aria-label="إغلاق">✕</button>
    </div>
  );
}
