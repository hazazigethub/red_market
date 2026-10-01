"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { markAllRead } from "@/app/me/actions";

/** Opening the notifications tab marks them read, then refreshes the header counter. */
export function AutoMarkRead() {
  const router = useRouter();
  useEffect(() => {
    markAllRead().then(() => router.refresh());
  }, [router]);
  return null;
}
