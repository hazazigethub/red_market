"use client";
import { useEffect, useRef, useState } from "react";
import {
  createLocalTracks, type LocalTrack, type RemoteTrack, Room, RoomEvent, Track, VideoPresets,
} from "livekit-client";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { functionsUrl } from "@/lib/env";
import { fmtNum } from "@/lib/format";
import { authHeaders, realtimeAuth } from "@/components/client/useSession";
import { track as trackEvent } from "@/components/client/Tracker";

async function getToken(streamId: string) {
  const res = await fetch(`${functionsUrl}/expo-stream/token`, {
    method: "POST", headers: await authHeaders(), body: JSON.stringify({ stream_id: streamId }),
  });
  if (!res.ok) throw new Error(`token ${res.status}`);
  return (await res.json()) as { token: string; url: string; can_publish: boolean };
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

/** Watch a live stream over WebRTC (sub-second latency). Starts muted to satisfy autoplay rules. */
export function StreamPlayer({ streamId, exhibitionId, status, recordingUrl, poster }: {
  streamId: string; exhibitionId: string; status: string; recordingUrl: string | null; poster?: string | null;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const audioRef = useRef<HTMLAudioElement>(null);
  const roomRef = useRef<Room | null>(null);
  const [state, setState] = useState<"connecting" | "waiting" | "playing" | "error">("connecting");
  const [muted, setMuted] = useState(true);

  useEffect(() => {
    if (status !== "live") return;
    const room = new Room({ adaptiveStream: true, dynacast: true });
    roomRef.current = room;
    const attach = (t: RemoteTrack) => {
      if (t.kind === Track.Kind.Video && videoRef.current) { t.attach(videoRef.current); setState("playing"); }
      if (t.kind === Track.Kind.Audio && audioRef.current) t.attach(audioRef.current);
    };
    room.on(RoomEvent.TrackSubscribed, attach)
      .on(RoomEvent.TrackUnsubscribed, (t) => t.detach())
      .on(RoomEvent.Disconnected, () => setState("waiting"));
    getToken(streamId)
      .then(({ token, url }) => room.connect(url, token))
      .then(() => {
        trackEvent({ exhibition_id: exhibitionId, stream_id: streamId, event: "stream_join" });
        room.remoteParticipants.forEach((p) => p.trackPublications.forEach((pub) => pub.track && attach(pub.track as RemoteTrack)));
        setState((s) => (s === "playing" ? s : "waiting"));
      })
      .catch(() => setState("error"));
    return () => { room.disconnect(); };
  }, [streamId, exhibitionId, status]);

  if (status !== "live") {
    if (recordingUrl) {
      return <video className="aspect-video w-full rounded-2xl bg-ink" src={recordingUrl} controls playsInline poster={poster ?? undefined} />;
    }
    return (
      <div className="grid aspect-video w-full place-items-center rounded-2xl bg-ink p-6 text-center text-bg">
        <p className="font-heading text-lg font-bold">
          {status === "scheduled" ? "لم يبدأ البث بعد" : "انتهى البث، والتسجيل قيد التجهيز"}
        </p>
      </div>
    );
  }

  return (
    <div className="relative aspect-video w-full overflow-hidden rounded-2xl bg-ink">
      <video ref={videoRef} className="h-full w-full object-contain" autoPlay playsInline muted />
      <audio ref={audioRef} autoPlay muted={muted} />
      {state !== "playing" && (
        <div className="absolute inset-0 grid place-items-center text-bg">
          <p className="text-sm">{state === "error" ? "تعذر الاتصال بالبث. حدّث الصفحة." : "جارٍ الاتصال بالبث…"}</p>
        </div>
      )}
      {state === "playing" && muted && (
        <button className="btn-primary btn-sm absolute bottom-3 right-3"
          onClick={async () => { await roomRef.current?.startAudio(); setMuted(false); }}>
          تشغيل الصوت
        </button>
      )}
    </div>
  );
}

/** Go live from the browser: camera + mic, no OBS needed. */
export function StreamStudio({ streamId, status: initialStatus }: { streamId: string; status: string }) {
  const previewRef = useRef<HTMLVideoElement>(null);
  const [tracks, setTracks] = useState<LocalTrack[]>([]);
  const [room, setRoom] = useState<Room | null>(null);
  const [status, setStatus] = useState(initialStatus);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const viewers = useStreamPresence(streamId);

  useEffect(() => () => { tracks.forEach((t) => t.stop()); room?.disconnect(); }, [tracks, room]);

  async function preview() {
    setErr(null);
    try {
      const t = await createLocalTracks({ audio: true, video: { resolution: VideoPresets.h720.resolution } });
      setTracks(t);
      const v = t.find((x) => x.kind === Track.Kind.Video);
      if (v && previewRef.current) v.attach(previewRef.current);
    } catch {
      setErr("اسمح للمتصفح باستخدام الكاميرا والميكروفون.");
    }
  }

  async function goLive() {
    setBusy(true); setErr(null);
    try {
      const { token, url, can_publish } = await getToken(streamId);
      if (!can_publish) throw new Error("no publish");
      const r = new Room({ dynacast: true });
      await r.connect(url, token);
      for (const t of tracks) await r.localParticipant.publishTrack(t);
      setRoom(r); setStatus("live");
    } catch {
      setErr("تعذر بدء البث. تأكد أن المعرض مجدول أو مباشر وأن لديك صلاحية البث.");
    }
    setBusy(false);
  }

  async function end() {
    setBusy(true);
    await fetch(`${functionsUrl}/expo-stream/end`, {
      method: "POST", headers: await authHeaders(), body: JSON.stringify({ stream_id: streamId }),
    });
    room?.disconnect(); tracks.forEach((t) => t.stop());
    setRoom(null); setTracks([]); setStatus("ended"); setBusy(false);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="relative aspect-video overflow-hidden rounded-2xl bg-ink">
        <video ref={previewRef} className="h-full w-full object-cover" autoPlay playsInline muted />
        {!tracks.length && <p className="absolute inset-0 grid place-items-center text-sm text-bg">المعاينة متوقفة</p>}
        {room && <div className="absolute top-3 right-3 flex items-center gap-2"><span className="badge-live"><span className="live-dot" />على الهواء</span>
          <span className="rounded-full bg-ink/70 px-2.5 py-0.5 text-xs text-bg">{viewers} مشاهد</span></div>}
      </div>
      <div className="flex flex-wrap gap-2">
        {!tracks.length && status !== "ended" && <button className="btn-ghost" onClick={preview}>تشغيل الكاميرا</button>}
        {tracks.length > 0 && !room && <button className="btn-primary" disabled={busy} onClick={goLive}>{busy ? "…" : "ابدأ البث"}</button>}
        {room && <button className="btn-ink" disabled={busy} onClick={end}>إنهاء البث</button>}
        {status === "ended" && <p className="text-sm text-muted">انتهى البث. سيظهر التسجيل للزوار عند اكتمال معالجته.</p>}
      </div>
      {err && <p className="text-sm text-primary" role="alert">{err}</p>}
    </div>
  );
}
