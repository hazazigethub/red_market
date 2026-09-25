"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

/** Link that stays highlighted (red) while its section is open. */
export function NavLink({ href, children, exact = false, also = [], className = "", activeClassName = "", inactiveClassName = "" }: {
  href: string; children: React.ReactNode; exact?: boolean; also?: string[];
  className?: string; activeClassName?: string; inactiveClassName?: string;
}) {
  const path = usePathname() ?? "";
  const match = (p: string) => path === p || path.startsWith(p + "/");
  const active = (exact ? path === href : match(href)) || also.some(match);
  return (
    <Link href={href} className={`${className} ${active ? activeClassName : inactiveClassName}`}
      aria-current={active ? "page" : undefined}>
      {children}
    </Link>
  );
}
