"use client";
import { useEffect, useState } from "react";

/** Renders children only on desktop (lg ≥ 1024px) or only on mobile — so a component mounts once. */
export function ScreenOnly({ desktop, children }: { desktop: boolean; children: React.ReactNode }) {
  const [show, setShow] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia("(min-width: 1024px)");
    const update = () => setShow(desktop ? mq.matches : !mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, [desktop]);
  return show ? <>{children}</> : null;
}
