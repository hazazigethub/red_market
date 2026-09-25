"use client";
import { arabicError } from "@/lib/errors";
export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="container-x flex flex-col items-center gap-4 py-24 text-center">
      <h1 className="text-2xl font-bold">تعذر إكمال العملية</h1>
      <p className="text-muted">{arabicError(error.message)}</p>
      <button className="btn-primary" onClick={reset}>حاول مرة أخرى</button>
    </div>
  );
}
