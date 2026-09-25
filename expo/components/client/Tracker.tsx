"use client";
import { useEffect } from "react";
import { functionsUrl } from "@/lib/env";
import { expoBrowser } from "@/lib/supabase/client";
import { authHeaders } from "@/components/client/useSession";

type Ev = { exhibition_id: string; booth_id?: string; stream_id?: string; event: string; props?: Record<string, unknown> };
let queue: (Ev & { anon_id: string })[] = [];
let timer: ReturnType<typeof setTimeout> | null = null;

function anonId() {
  try {
    let id = localStorage.getItem("expo_anon");
    if (!id) { id = crypto.randomUUID(); localStorage.setItem("expo_anon", id); }
    return id;
  } catch { return "na"; }
}

async function flush() {
  if (!queue.length) return;
  const events = queue.splice(0, 50);
  try {
    await fetch(`${functionsUrl}/expo-track`, {
      method: "POST", keepalive: true, headers: await authHeaders(), body: JSON.stringify({ events }),
    });
  } catch { /* analytics must never break the page */ }
}

export function track(ev: Ev) {
  queue.push({ ...ev, anon_id: anonId() });
  if (!timer) timer = setTimeout(() => { timer = null; flush(); }, 4000);
}

/** Records the page view (and the visit, for signed-in users). */
export function Tracker(props: Ev & { recordVisit?: boolean }) {
  const { exhibition_id, booth_id, stream_id, event, recordVisit } = props;
  useEffect(() => {
    track({ exhibition_id, booth_id, stream_id, event });
    if (recordVisit) {
      const src = new URLSearchParams(location.search).get("utm_source") ?? (document.referrer.includes("redmarket.pro") ? "redmarket" : "direct");
      expoBrowser().rpc("record_visit", { p_exhibition: exhibition_id, p_source: src }).then(() => {});
    }
    const onHide = () => document.visibilityState === "hidden" && flush();
    document.addEventListener("visibilitychange", onHide);
    return () => document.removeEventListener("visibilitychange", onHide);
  }, [exhibition_id, booth_id, stream_id, event, recordVisit]);
  return null;
}

/** Outbound link that records an analytics event (e.g. "buy on Red Market"). */
export function TrackedLink({ ev, children, ...a }: React.AnchorHTMLAttributes<HTMLAnchorElement> & { ev: Ev }) {
  return <a {...a} onClick={() => { track(ev); flush(); }}>{children}</a>;
}
