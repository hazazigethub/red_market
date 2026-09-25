import "server-only";
import { redirect } from "next/navigation";

/** Server-action failures travel back as ?error=CODE so the page can show a clear Arabic message
 *  (production builds hide thrown error messages). */
export function failTo(path: string, error: { message: string } | null | undefined): void {
  if (!error) return;
  const sep = path.includes("?") ? "&" : "?";
  redirect(`${path}${sep}error=${encodeURIComponent(error.message.slice(0, 160))}`);
}

export const str = (f: FormData, k: string) => {
  const v = f.get(k);
  return typeof v === "string" && v.trim() ? v.trim() : null;
};
export const bool = (f: FormData, k: string) => f.get(k) === "on" || f.get(k) === "true";
export const num = (f: FormData, k: string) => {
  const v = str(f, k);
  return v == null || Number.isNaN(Number(v)) ? null : Number(v);
};
