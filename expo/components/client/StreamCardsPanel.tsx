"use client";
import { useEffect, useState } from "react";
import { arabicError } from "@/lib/errors";
import { expoBrowser } from "@/lib/supabase/client";

/** Exhibitor controls under the pinned product: send cards to the stream chat + visitors writing switch. */
export function StreamCardsPanel({ chatId, products, catalogs }: {
  chatId: string;
  products: { product_id: string; name: string }[];
  catalogs: { id: string; title: string | null }[];
}) {
  const [product, setProduct] = useState(products[0]?.product_id ?? "");
  const [catalog, setCatalog] = useState(catalogs[0]?.id ?? "");
  const [open, setOpen] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    expoBrowser().from("exhibition_chats").select("visitors_muted").eq("id", chatId).maybeSingle()
      .then(({ data }) => { if (data) setOpen(!data.visitors_muted); });
  }, [chatId]);

  async function send(kind: "product_card" | "catalog" | "contact_card", ref: string | null, label: string) {
    setBusy(kind); setMsg(null);
    const { error } = await expoBrowser().rpc("send_chat_card", { p_chat: chatId, p_kind: kind, p_ref: ref });
    setBusy(null);
    setMsg(error ? { ok: false, text: arabicError(error.message) } : { ok: true, text: `أُرسل ${label} إلى المحادثة` });
  }

  async function toggleWriting() {
    const next = !open;
    setBusy("mute"); setMsg(null);
    const { error } = await expoBrowser().from("exhibition_chats").update({ visitors_muted: !next }).eq("id", chatId);
    setBusy(null);
    if (error) return setMsg({ ok: false, text: arabicError(error.message) });
    setOpen(next);
  }

  return (
    <div className="card flex flex-col gap-4 p-4">
      <h3 className="font-heading font-bold">إرسال إلى المحادثة</h3>

      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-48 flex-1"><label className="label" htmlFor="card-product">منتج</label>
          <select id="card-product" className="input" value={product} onChange={(e) => setProduct(e.target.value)} disabled={!products.length}>
            {products.length ? products.map((p) => <option key={p.product_id} value={p.product_id}>{p.name}</option>)
              : <option value="">لا توجد منتجات في الجناح</option>}
          </select></div>
        <button className="btn-ghost" disabled={!product || busy !== null} onClick={() => send("product_card", product, "المنتج")}>إرسال</button>
      </div>

      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-48 flex-1"><label className="label" htmlFor="card-catalog">كتالوج</label>
          <select id="card-catalog" className="input" value={catalog} onChange={(e) => setCatalog(e.target.value)} disabled={!catalogs.length}>
            {catalogs.length ? catalogs.map((c) => <option key={c.id} value={c.id}>{c.title ?? "كتالوج"}</option>)
              : <option value="">لا توجد كتالوجات في الجناح</option>}
          </select></div>
        <button className="btn-ghost" disabled={!catalog || busy !== null} onClick={() => send("catalog", catalog, "الكتالوج")}>إرسال</button>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <p className="flex-1 text-sm">بطاقة التاجر <span className="text-xs text-muted">(من بيانات التواصل الظاهرة للزوار)</span></p>
        <button className="btn-ghost" disabled={busy !== null} onClick={() => send("contact_card", null, "بطاقة التاجر")}>إرسال</button>
      </div>

      <div className="flex items-center gap-3 border-t border-line pt-4">
        <p className="flex-1 text-sm">السماح للزوار بالكتابة في المحادثة</p>
        <button role="switch" aria-checked={open} aria-label="السماح للزوار بالكتابة" disabled={busy !== null} onClick={toggleWriting}
          className={`relative h-6 w-11 rounded-full transition ${open ? "bg-success" : "bg-line"}`}>
          <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${open ? "right-0.5" : "right-[1.375rem]"}`} />
        </button>
      </div>

      {msg && <p role="status" className={`text-sm ${msg.ok ? "text-success" : "text-primary"}`}>{msg.text}</p>}
    </div>
  );
}
