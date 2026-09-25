"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { realtimeAuth } from "@/components/client/useSession";

/** Refreshes the booth inbox / leads list when a visitor writes or a new lead arrives. */
export function InboxLive({ boothId }: { boothId: string }) {
  const router = useRouter();
  useEffect(() => {
    let ch: RealtimeChannel | null = null;
    realtimeAuth().then((sb) => {
      ch = sb.channel(`booth-inbox:${boothId}`, { config: { private: true } })
        .on("broadcast", { event: "message" }, () => router.refresh())
        .on("broadcast", { event: "lead" }, () => router.refresh())
        .subscribe();
    });
    return () => { ch?.unsubscribe(); };
  }, [boothId, router]);
  return null;
}
