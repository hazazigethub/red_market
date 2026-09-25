"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { arabicError } from "@/lib/errors";
import { expoBrowser, supabaseBrowser } from "@/lib/supabase/client";
import { publicUrl } from "@/lib/storage";
import { functionsUrl } from "@/lib/env";
import { authHeaders } from "@/components/client/useSession";

async function upload(bucket: string, prefix: string, file: File) {
  const ext = file.name.split(".").pop()?.toLowerCase().replace(/[^a-z0-9]/g, "") || "bin";
  const path = `${prefix}/${crypto.randomUUID()}.${ext}`;
  const { error } = await supabaseBrowser().storage.from(bucket).upload(path, file, {
    cacheControl: "31536000", contentType: file.type, upsert: false,
  });
  if (error) throw error;
  return path;
}

/** Image field for server-action forms: uploads first, then submits the storage path in a hidden input. */
export function ImageField({ name, label, prefix, initial, aspect = "square" }: {
  name: string; label: string; prefix: string; initial?: string | null; aspect?: "square" | "wide";
}) {
  const [path, setPath] = useState(initial ?? "");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const src = publicUrl(path);
  return (
    <div>
      <span className="label">{label}</span>
      <div className="flex items-center gap-3">
        <div className={`overflow-hidden rounded-xl border border-line bg-bg ${aspect === "wide" ? "h-20 w-40" : "h-20 w-20"}`}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          {src && <img src={src} alt="" className="h-full w-full object-cover" />}
        </div>
        <label className="btn-ghost btn-sm cursor-pointer">
          {busy ? "جارٍ الرفع…" : path ? "تغيير" : "رفع صورة"}
          <input type="file" accept="image/png,image/jpeg,image/webp" className="sr-only" disabled={busy}
            onChange={async (e) => {
              const f = e.target.files?.[0]; if (!f) return;
              if (f.size > 5 * 1024 * 1024) return setErr("الحد الأقصى 5 ميجابايت.");
              setBusy(true); setErr(null);
              try { setPath(await upload("expo-public", prefix, f)); } catch (x) { setErr(arabicError((x as Error).message)); }
              setBusy(false);
            }} />
        </label>
        {path && <button type="button" className="text-xs text-muted hover:text-primary" onClick={() => setPath("")}>إزالة</button>}
      </div>
      <input type="hidden" name={name} value={path} />
      {err && <p className="mt-1 text-xs text-primary">{err}</p>}
    </div>
  );
}

const LIMITS = { image: 5, video: 500, catalog: 25 };

export function MediaUploader({ boothId }: { boothId: string }) {
  const router = useRouter();
  const [type, setType] = useState<"image" | "video" | "catalog">("image");
  const [gated, setGated] = useState(true);
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const accept = type === "image" ? "image/png,image/jpeg,image/webp" : type === "video" ? "video/mp4,video/webm" : "application/pdf";

  return (
    <div className="card flex flex-col gap-4 p-5">
      <h3 className="font-heading text-lg font-bold">إضافة ملف</h3>
      <div className="flex gap-2" role="radiogroup" aria-label="نوع الملف">
        {(["image", "video", "catalog"] as const).map((t) => (
          <button key={t} type="button" role="radio" aria-checked={type === t}
            className={type === t ? "btn-ink btn-sm" : "btn-ghost btn-sm"} onClick={() => setType(t)}>
            {t === "image" ? "صورة" : t === "video" ? "فيديو" : "كتالوج PDF"}
          </button>
        ))}
      </div>
      <div><label className="label" htmlFor="m-title">العنوان</label>
        <input id="m-title" className="input" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} /></div>
      {type === "catalog" && (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" className="h-4 w-4 accent-[#C21815]" checked={gated} onChange={(e) => setGated(e.target.checked)} />
          كتالوج محمي: يشارك الزائر بيانات تواصله قبل التنزيل (يُسجَّل كعميل محتمل)
        </label>
      )}
      <label className={`btn-primary cursor-pointer self-start ${busy ? "opacity-50" : ""}`}>
        {busy ? "جارٍ الرفع…" : "اختر الملف"}
        <input type="file" accept={accept} className="sr-only" disabled={busy} onChange={async (e) => {
          const f = e.target.files?.[0]; if (!f) return;
          if (f.size > LIMITS[type] * 1024 * 1024) return setErr(`الحد الأقصى ${LIMITS[type]} ميجابايت.`);
          setBusy(true); setErr(null);
          try {
            const path = await upload(type === "catalog" ? "expo-catalogs" : "expo-public", `booths/${boothId}/${type}`, f);
            const { error } = await expoBrowser().from("booth_media").insert({
              booth_id: boothId, type, storage_path: path, title: title || f.name.replace(/\.[^.]+$/, ""),
              size_bytes: f.size, is_gated: type === "catalog" && gated,
            });
            if (error) throw error;
            setTitle(""); router.refresh();
          } catch (x) { setErr(arabicError((x as Error).message)); }
          setBusy(false); e.target.value = "";
        }} />
      </label>
      {err && <p className="text-sm text-primary">{err}</p>}
    </div>
  );
}

export function ExportLeadsButton({ boothId, status }: { boothId: string; status?: string }) {
  const [busy, setBusy] = useState(false);
  return (
    <button className="btn-ghost btn-sm" disabled={busy} onClick={async () => {
      setBusy(true);
      const qs = new URLSearchParams({ booth_id: boothId, ...(status ? { status } : {}) });
      const res = await fetch(`${functionsUrl}/expo-leads?${qs}`, { headers: await authHeaders() });
      setBusy(false);
      if (!res.ok) return alert("التصدير متاح لمالك الجناح والمدير فقط.");
      const blob = await res.blob();
      const a = Object.assign(document.createElement("a"), { href: URL.createObjectURL(blob), download: `leads-${boothId.slice(0, 8)}.csv` });
      a.click(); URL.revokeObjectURL(a.href);
    }}>{busy ? "…" : "تصدير CSV"}</button>
  );
}
