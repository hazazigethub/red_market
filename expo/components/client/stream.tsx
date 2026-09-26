"use client";
import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { env, functionsUrl } from "@/lib/env";
import { fmtNum } from "@/lib/format";
import { authHeaders, realtimeAuth } from "@/components/client/useSession";
import { track as trackEvent } from "@/components/client/Tracker";

async function streamCall(action: "start" | "end", streamId: string) {
  const res = await fetch(`${functionsUrl}/expo-stream/${action}`, {
    method: "POST", headers: await authHeaders(), body: JSON.stringify({ stream_id: streamId }),
  });
  if (!res.ok) throw new Error(`${action} ${res.status}`);
  return res.json() as Promise<{ whip_url?: string; input_id?: string; ok?: boolean }>;
}

/** Viewer presence + like bursts on the private "stream:{id}" channel. */
export function useStreamPresence(streamId: string, onLike?: (count: number) => void) {
  const [viewers, setViewers] = useState(0);
  const likeRef = useRef(onLike);
  likeRef.current = onLike;
  useEffect(() => {
    let ch: RealtimeChannel | null = null;
    realtimeAuth().then((sb) => {
      ch = sb.channel(`stream:${streamId}`, { config: { private: true, presence: { key: crypto.randomUUID() } } })
        .on("presence", { event: "sync" }, () => setViewers(Object.keys(ch!.presenceState()).length))
        .on("broadcast", { event: "like" }, ({ payload }) => likeRef.current?.(payload.count))
        .subscribe(async (status) => { if (status === "SUBSCRIBED") await ch!.track({ at: Date.now() }); });
    });
    return () => { ch?.unsubscribe(); };
  }, [streamId]);
  return viewers;
}

export function ViewerCount({ streamId, fallback }: { streamId: string; fallback: number }) {
  const n = useStreamPresence(streamId);
  return <span className="text-sm text-muted">{fmtNum(Math.max(n, fallback))} يشاهد الآن</span>;
}

/** Watch a live stream (Cloudflare Stream player). Starts muted to satisfy autoplay rules. */
export function StreamPlayer({ streamId, exhibitionId, status, recordingUrl, poster, inputId }: {
  streamId: string; exhibitionId: string; status: string; recordingUrl: string | null;
  poster?: string | null; inputId?: string | null;
}) {
  useEffect(() => {
    if (status === "live") trackEvent({ exhibition_id: exhibitionId, stream_id: streamId, event: "stream_join" });
  }, [streamId, exhibitionId, status]);

  if (status === "live" && inputId && env.cfStreamSubdomain) {
    return (
      <div className="relative aspect-video w-full overflow-hidden rounded-2xl bg-ink">
        <iframe
          src={`https://${env.cfStreamSubdomain}/${inputId}/iframe?autoplay=true&muted=true&preload=auto`}
          className="absolute inset-0 h-full w-full border-0"
          allow="accelerometer; gyroscope; autoplay; encrypted-media; picture-in-picture; fullscreen"
          allowFullScreen
          title="البث المباشر"
        />
      </div>
    );
  }
  if (recordingUrl) {
    return <video className="aspect-video w-full rounded-2xl bg-ink" src={recordingUrl} controls playsInline poster={poster ?? undefined} />;
  }
  return (
    <div className="grid aspect-video w-full place-items-center rounded-2xl bg-ink p-6 text-center text-bg">
      <p className="font-heading text-lg font-bold">
        {status === "scheduled" ? "لم يبدأ البث بعد" : status === "live" ? "جارٍ تجهيز البث…" : "انتهى البث"}
      </p>
    </div>
  );
}

/** Wait until ICE candidates are gathered (WHIP sends a single offer). */
function iceGathered(pc: RTCPeerConnection, ms = 2500) {
  return new Promise<void>((resolve) => {
    if (pc.iceGatheringState === "complete") return resolve();
    const done = () => { pc.removeEventListener("icegatheringstatechange", check); resolve(); };
    const check = () => { if (pc.iceGatheringState === "complete") done(); };
    pc.addEventListener("icegatheringstatechange", check);
    setTimeout(done, ms);
  });
}

/** Go live from the browser: camera + mic sent to Cloudflare over WebRTC (WHIP), no OBS needed. */
export function StreamStudio({ streamId, status: initialStatus }: { streamId: string; status: string }) {
  const previewRef = useRef<HTMLVideoElement>(null);
  const [media, setMedia] = useState<MediaStream | null>(null);
  const [pc, setPc] = useState<RTCPeerConnection | null>(null);
  const resourceRef = useRef<string | null>(null);
  const [status, setStatus] = useState(initialStatus);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const viewers = useStreamPresence(streamId);

  useEffect(() => () => { media?.getTracks().forEach((t) => t.stop()); pc?.close(); }, [media, pc]);

  async function preview() {
    setErr(null);
    try {
      const m = await navigator.mediaDevices.getUserMedia({
        audio: true, video: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } },
      });
      setMedia(m);
      if (previewRef.current) previewRef.current.srcObject = m;
    } catch {
      setErr("اسمح للمتصفح باستخدام الكاميرا والميكروفون.");
    }
  }

  async function goLive() {
    if (!media) return;
    setBusy(true); setErr(null);
    try {
      const { whip_url } = await streamCall("start", streamId);
      if (!whip_url) throw new Error("no whip");
      const conn = new RTCPeerConnection({ iceServers: [{ urls: "stun:stun.cloudflare.com:3478" }], bundlePolicy: "max-bundle" });
      media.getTracks().forEach((t) => conn.addTransceiver(t, { direction: "sendonly" }));
      await conn.setLocalDescription(await conn.createOffer());
      await iceGathered(conn);
      const res = await fetch(whip_url, {
        method: "POST", headers: { "Content-Type": "application/sdp" }, body: conn.localDescription!.sdp,
      });
      if (!res.ok) throw new Error(`whip ${res.status}`);
      const loc = res.headers.get("Location");
      resourceRef.current = loc ? new URL(loc, whip_url).toString() : null;
      await conn.setRemoteDescription({ type: "answer", sdp: await res.text() });
      setPc(conn); setStatus("live");
    } catch {
      setErr("تعذر بدء البث. تأكد أن المعرض مجدول أو مباشر وأن لديك صلاحية البث.");
    }
    setBusy(false);
  }

  async function end() {
    setBusy(true);
    if (resourceRef.current) await fetch(resourceRef.current, { method: "DELETE" }).catch(() => {});
    pc?.close();
    await streamCall("end", streamId).catch(() => {});
    media?.getTracks().forEach((t) => t.stop());
    setPc(null); setMedia(null); setStatus("ended"); setBusy(false);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="relative aspect-video overflow-hidden rounded-2xl bg-ink">
        <video ref={previewRef} className="h-full w-full object-cover" autoPlay playsInline muted />
        {!media && <p className="absolute inset-0 grid place-items-center text-sm text-bg">المعاينة متوقفة</p>}
        {pc && <div className="absolute top-3 right-3 flex items-center gap-2"><span className="badge-live"><span className="live-dot" />على الهواء</span>
          <span className="rounded-full bg-ink/70 px-2.5 py-0.5 text-xs text-bg">{viewers} مشاهد</span></div>}
      </div>
      <div className="flex flex-wrap gap-2">
        {!media && status !== "ended" && <button className="btn-ghost" onClick={preview}>تشغيل الكاميرا</button>}
        {media && !pc && <button className="btn-primary" disabled={busy} onClick={goLive}>{busy ? "…" : "ابدأ البث"}</button>}
        {pc && <button className="btn-ink" disabled={busy} onClick={end}>إنهاء البث</button>}
        {status === "ended" && <p className="text-sm text-muted">انتهى البث.</p>}
      </div>
      {err && <p className="text-sm text-primary" role="alert">{err}</p>}
    </div>
  );
}
