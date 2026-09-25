"use client";
import { useState, useTransition } from "react";
import { loginUrl } from "@/lib/env";
import { arabicError } from "@/lib/errors";
import { fmtNum } from "@/lib/format";
import { expoBrowser } from "@/lib/supabase/client";
import { track } from "@/components/client/Tracker";

function goLogin() { location.href = loginUrl(location.pathname + location.search); }

export function FollowButton({ boothId, initial, count, signedIn }: { boothId: string; initial: boolean; count: number; signedIn: boolean }) {
  const [on, setOn] = useState(initial);
  const [n, setN] = useState(count);
  const [pending, start] = useTransition();
  return (
    <button className={on ? "btn-ink" : "btn-ghost"} disabled={pending} aria-pressed={on}
      onClick={() => {
        if (!signedIn) return goLogin();
        start(async () => {
          const { data, error } = await expoBrowser().rpc("toggle_follow", { p_booth: boothId });
          if (error) return alert(arabicError(error.message));
          setOn(data.following); setN(data.count);
        });
      }}>
      {on ? "تتابعه" : "متابعة"} <span className="text-xs opacity-70">{fmtNum(n)}</span>
    </button>
  );
}

export function LikeButton({ type, id, initial, count, signedIn }: {
  type: "booth" | "stream" | "product"; id: string; initial: boolean; count: number; signedIn: boolean;
}) {
  const [on, setOn] = useState(initial);
  const [n, setN] = useState(count);
  const [pending, start] = useTransition();
  return (
    <button className="btn-ghost" disabled={pending} aria-pressed={on} aria-label="إعجاب"
      onClick={() => {
        if (!signedIn) return goLogin();
        setOn(!on); setN(n + (on ? -1 : 1));
        start(async () => {
          const { data, error } = await expoBrowser().rpc("toggle_like", { p_type: type, p_id: id });
          if (error) { setOn(on); setN(n); return alert(arabicError(error.message)); }
          setOn(data.liked); setN(data.count);
        });
      }}>
      <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden fill={on ? "#C21815" : "none"} stroke={on ? "#C21815" : "currentColor"} strokeWidth="2">
        <path d="M12 21s-7.5-4.6-9.5-9.3C1.2 8.4 3.3 5 6.8 5c2 0 3.4 1.1 4.2 2.3C11.8 6.1 13.2 5 15.2 5c3.5 0 5.6 3.4 4.3 6.7C19.5 16.4 12 21 12 21z" />
      </svg>
      {fmtNum(n)}
    </button>
  );
}

export function ShareButton({ title, exhibitionId, boothId }: { title: string; exhibitionId: string; boothId?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button className="btn-ghost" onClick={async () => {
      track({ exhibition_id: exhibitionId, booth_id: boothId, event: "share" });
      const url = location.href;
      if (navigator.share) { try { await navigator.share({ title, url }); return; } catch { /* dismissed */ } }
      await navigator.clipboard.writeText(url);
      setCopied(true); setTimeout(() => setCopied(false), 2000);
    }}>
      {copied ? "تم نسخ الرابط" : "مشاركة"}
    </button>
  );
}

export function RegisterButton({ sessionId, initial, full, signedIn }: { sessionId: string; initial: boolean; full: boolean; signedIn: boolean }) {
  const [on, setOn] = useState(initial);
  const [pending, start] = useTransition();
  if (full && !on) return <span className="badge">اكتمل العدد</span>;
  return (
    <button className={on ? "btn-ghost btn-sm" : "btn-primary btn-sm"} disabled={pending}
      onClick={() => {
        if (!signedIn) return goLogin();
        start(async () => {
          const { error } = await expoBrowser().rpc("register_session", { p_session: sessionId, p_register: !on });
          if (error) return alert(arabicError(error.message));
          setOn(!on);
        });
      }}>
      {on ? "مسجّل ✓ إلغاء" : "سجّل حضورك"}
    </button>
  );
}
