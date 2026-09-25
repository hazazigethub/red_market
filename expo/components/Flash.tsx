import { arabicError } from "@/lib/errors";

export function Flash({ error, ok }: { error?: string; ok?: string }) {
  if (error) return <p role="alert" className="mb-4 rounded-[10px] border border-primary/30 bg-tint p-3 text-sm text-primary-dark">{arabicError(error)}</p>;
  if (ok) return <p role="status" className="mb-4 rounded-[10px] border border-success/30 bg-success/10 p-3 text-sm text-success">{ok}</p>;
  return null;
}
