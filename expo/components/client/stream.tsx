"use client";
import { useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { env, functionsUrl } from "@/lib/env";
import { expoBrowser } from "@/lib/supabase/client";
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
        .on("broadcast", { event: "like" }, ({ payload }) => {
          likeRef.current?.(payload.count);
          // show "❤ name liked the stream" inside the chat (not stored)
          window.dispatchEvent(new CustomEvent("expo:stream-like", { detail: { streamId, name: payload.name ?? null } }));
        })
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

/** Watch a live stream over WebRTC (WHEP) — required for streams broadcast from the browser (WHIP).
 *  Starts muted to satisfy autoplay rules. */
export function StreamPlayer({ streamId, exhibitionId, status, recordingUrl, poster, inputId, overlay }: {
  streamId: string; exhibitionId: string; status: string; recordingUrl: string | null;
  poster?: string | null; inputId?: string | null;
  /** طبقة فوق الفيديو (الدردشة في الجوال) */
  overlay?: React.ReactNode;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [state, setState] = useState<"connecting" | "playing" | "reconnecting">("connecting");
  const [muted, setMuted] = useState(true);
  const live = status === "live" && !!inputId && !!env.cfStreamSubdomain;

  useEffect(() => {
    if (status === "live") trackEvent({ exhibition_id: exhibitionId, stream_id: streamId, event: "stream_join" });
  }, [streamId, exhibitionId, status]);

  // WHEP playback that survives drops: shows "connection issue" at once and keeps retrying
  useEffect(() => {
    if (!live) return;
    const url = `https://${env.cfStreamSubdomain}/${inputId}/webRTC/play`;
    let stopped = false;
    let pc: RTCPeerConnection | null = null;
    let resource: string | null = null;
    let retry: ReturnType<typeof setTimeout> | null = null;
    let muteTimer: ReturnType<typeof setTimeout> | null = null;
    let played = false;

    const cleanup = () => {
      if (muteTimer) { clearTimeout(muteTimer); muteTimer = null; }
      if (resource) fetch(resource, { method: "DELETE" }).catch(() => {});
      resource = null;
      pc?.close();
      pc = null;
    };
    const reconnect = () => {
      if (stopped || retry) return;
      cleanup();
      setState(played ? "reconnecting" : "connecting");
      retry = setTimeout(() => { retry = null; connect(); }, 4000);
    };

    async function connect() {
      if (stopped) return;
      const conn = new RTCPeerConnection({ iceServers: [{ urls: "stun:stun.cloudflare.com:3478" }], bundlePolicy: "max-bundle" });
      pc = conn;
      conn.addTransceiver("video", { direction: "recvonly" });
      conn.addTransceiver("audio", { direction: "recvonly" });
      const stream = new MediaStream();
      conn.ontrack = (ev) => {
        stream.addTrack(ev.track);
        if (videoRef.current && videoRef.current.srcObject !== stream) videoRef.current.srcObject = stream;
        if (ev.track.kind === "video") {
          // no picture arriving = the exhibitor dropped; reconnect if it lasts
          ev.track.onmute = () => {
            if (pc !== conn) return;
            setState("reconnecting");
            if (!muteTimer) muteTimer = setTimeout(() => { muteTimer = null; if (pc === conn) reconnect(); }, 6000);
          };
          ev.track.onunmute = () => {
            if (muteTimer) { clearTimeout(muteTimer); muteTimer = null; }
            if (pc === conn) { played = true; setState("playing"); }
          };
        }
        played = true;
        setState("playing");
      };
      conn.onconnectionstatechange = () => {
        if (pc === conn && (conn.connectionState === "failed" || conn.connectionState === "closed")) reconnect();
      };
      try {
        await conn.setLocalDescription(await conn.createOffer());
        await iceGathered(conn);
        const res = await fetch(url, { method: "POST", headers: { "Content-Type": "application/sdp" }, body: conn.localDescription!.sdp });
        if (!res.ok) throw new Error(`whep ${res.status}`);
        const loc = res.headers.get("Location");
        resource = loc ? new URL(loc, url).toString() : null;
        if (pc === conn) await conn.setRemoteDescription({ type: "answer", sdp: await res.text() });
      } catch {
        if (pc === conn) reconnect();
      }
    }

    connect();
    return () => { stopped = true; if (retry) clearTimeout(retry); cleanup(); };
  }, [live, inputId]);

  if (live) {
    return (
      <div className="relative h-[72vh] w-full overflow-hidden rounded-2xl bg-ink lg:h-auto lg:aspect-video">
        <video ref={videoRef} className="h-full w-full object-contain" autoPlay playsInline muted={muted} />
        {overlay && <div className="absolute inset-x-0 bottom-0 h-[55%] lg:hidden">{overlay}</div>}
        {state !== "playing" && (
          <div className="absolute inset-0 grid place-items-center text-bg">
            <p className="px-6 text-center text-sm">{state === "reconnecting" ? "العارض يواجه مشكلة في الاتصال… سيعود البث تلقائياً" : "جارٍ الاتصال بالبث…"}</p>
          </div>
        )}
        {state === "playing" && (
          <button className={`btn-sm absolute top-3 left-3 ${muted ? "btn-primary" : "btn-ink"}`}
            onClick={() => setMuted((m) => !m)} aria-pressed={!muted}>
            {muted ? "تشغيل الصوت" : "كتم الصوت"}
          </button>
        )}
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
  const [micOn, setMicOn] = useState(true);
  const [camOn, setCamOn] = useState(true);
  const viewers = useStreamPresence(streamId);

  // mute / camera off keep the broadcast running (silence / black frame)
  function toggleMic() {
    const next = !micOn;
    media?.getAudioTracks().forEach((t) => { t.enabled = next; });
    setMicOn(next);
  }
  function toggleCam() {
    const next = !camOn;
    media?.getVideoTracks().forEach((t) => { t.enabled = next; });
    setCamOn(next);
  }

  // stop the camera and close the connection only when leaving the page
  // (not when the connection starts — that used to switch the camera off)
  const mediaRef = useRef<MediaStream | null>(null);
  const pcRef = useRef<RTCPeerConnection | null>(null);
  mediaRef.current = media;
  pcRef.current = pc;
  useEffect(() => () => {
    mediaRef.current?.getTracks().forEach((t) => t.stop());
    pcRef.current?.close();
  }, []);

  // "still broadcasting" signal: without it for 2 minutes the stream is ended automatically
  useEffect(() => {
    if (!pc) return;
    const beat = () => { expoBrowser().rpc("stream_heartbeat", { p_stream: streamId }).then(() => {}); };
    beat();
    const t = setInterval(beat, 15_000);
    return () => clearInterval(t);
  }, [pc, streamId]);

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

  const whipRef = useRef<string | null>(null);
  const endingRef = useRef(false);
  const [reconnecting, setReconnecting] = useState(false);

  /** send camera + mic to Cloudflare (WHIP); reconnects by itself if the internet drops */
  async function publish(whipUrl: string, m: MediaStream): Promise<RTCPeerConnection> {
    const conn = new RTCPeerConnection({ iceServers: [{ urls: "stun:stun.cloudflare.com:3478" }], bundlePolicy: "max-bundle" });
    m.getTracks().forEach((t) => conn.addTransceiver(t, { direction: "sendonly" }));
    await conn.setLocalDescription(await conn.createOffer());
    await iceGathered(conn);
    const res = await fetch(whipUrl, { method: "POST", headers: { "Content-Type": "application/sdp" }, body: conn.localDescription!.sdp });
    if (!res.ok) { conn.close(); throw new Error(`whip ${res.status}`); }
    const loc = res.headers.get("Location");
    resourceRef.current = loc ? new URL(loc, whipUrl).toString() : null;
    await conn.setRemoteDescription({ type: "answer", sdp: await res.text() });
    conn.onconnectionstatechange = () => {
      const st = conn.connectionState;
      if (st === "failed" || st === "disconnected") {
        // give a short blip 3 seconds to recover on its own
        setTimeout(() => {
          if (pcRef.current === conn && conn.connectionState !== "connected") recover(conn);
        }, st === "failed" ? 0 : 3000);
      }
    };
    return conn;
  }

  async function recover(old: RTCPeerConnection) {
    if (endingRef.current || pcRef.current !== old || !whipRef.current || !mediaRef.current) return;
    setReconnecting(true);
    old.close();
    try {
      // marks the same stream live again (in case the outage passed the 1-minute limit)
      const { whip_url } = await streamCall("start", streamId);
      if (whip_url) whipRef.current = whip_url;
      const conn = await publish(whipRef.current!, mediaRef.current);
      pcRef.current = conn;
      setPc(conn);
      setReconnecting(false);
    } catch {
      setTimeout(() => recover(old), 3000);   // keep trying until back online (or ended)
      return;
    }
  }

  async function goLive() {
    if (!media) return;
    setBusy(true); setErr(null);
    endingRef.current = false;
    try {
      const { whip_url } = await streamCall("start", streamId);
      if (!whip_url) throw new Error("no whip");
      whipRef.current = whip_url;
      const conn = await publish(whip_url, media);
      pcRef.current = conn;
      setPc(conn); setStatus("live");
    } catch {
      setErr("تعذر بدء البث. تأكد أن المعرض مجدول أو مباشر وأن لديك صلاحية البث.");
    }
    setBusy(false);
  }

  async function end() {
    endingRef.current = true;
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
        {media && !camOn && <p className="absolute inset-0 grid place-items-center bg-ink text-sm text-bg">الكاميرا متوقفة</p>}
        {media && !micOn && <span className="absolute bottom-3 right-3 rounded-full bg-ink/70 px-2.5 py-0.5 text-xs text-bg">المايك مكتوم</span>}
        {reconnecting && <p className="absolute inset-x-0 bottom-3 mx-auto w-fit rounded-full bg-primary px-3 py-1 text-xs font-bold text-white">انقطع الاتصال… جارٍ إعادة الاتصال</p>}
        {pc && <div className="absolute top-3 right-3 flex items-center gap-2"><span className="badge-live"><span className="live-dot" />على الهواء</span>
          <span className="rounded-full bg-ink/70 px-2.5 py-0.5 text-xs text-bg">{viewers} مشاهد</span></div>}
      </div>
      <div className="flex flex-wrap gap-2">
        {!media && status !== "ended" && <button className="btn-ghost" onClick={preview}>تشغيل الكاميرا</button>}
        {media && (
          <>
            <button className={micOn ? "btn-ghost" : "btn-ink"} onClick={toggleMic} aria-pressed={!micOn}>
              {micOn ? "كتم المايك" : "تشغيل المايك"}
            </button>
            <button className={camOn ? "btn-ghost" : "btn-ink"} onClick={toggleCam} aria-pressed={!camOn}>
              {camOn ? "إيقاف الكاميرا" : "تشغيل الكاميرا"}
            </button>
          </>
        )}
        {media && !pc && <button className="btn-primary" disabled={busy} onClick={goLive}>{busy ? "…" : "ابدأ البث"}</button>}
        {pc && <button className="btn-ink" disabled={busy} onClick={end}>إنهاء البث</button>}
        {status === "ended" && <p className="text-sm text-muted">انتهى البث.</p>}
      </div>
      {err && <p className="text-sm text-primary" role="alert">{err}</p>}
    </div>
  );
}
