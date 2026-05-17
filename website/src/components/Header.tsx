"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import { useState } from "react";

const NAV = [
  { href: "/", label: "Home" },
  { href: "/downloads/", label: "Downloads" },
  { href: "/packages/", label: "Packages" },
  { href: "/docs/", label: "Documentation" },
  { href: "https://github.com/V0rtexLinux/V0rtexOS", label: "GitHub", external: true },
];

export function Header() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-vortex-border/80 bg-vortex-bg/90 backdrop-blur-md">
      <div className="vortex-container flex h-16 items-center justify-between">
        <Link href="/" className="flex items-center gap-2 font-bold tracking-tight">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-cyan-400 to-violet-500 text-sm font-black text-vortex-bg">
            V0
          </span>
          <span>
            V0rtex<span className="text-cyan-400">OS</span>
          </span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {NAV.map((item) => {
            const active =
              item.href === "/"
                ? pathname === "/"
                : pathname.startsWith(item.href.replace(/\/$/, ""));
            const cls = active
              ? "bg-vortex-card text-cyan-400"
              : "text-slate-400 hover:text-white";
            if (item.external) {
              return (
                <a
                  key={item.href}
                  href={item.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={`rounded-lg px-3 py-2 text-sm font-medium transition ${cls}`}
                >
                  {item.label}
                </a>
              );
            }
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`rounded-lg px-3 py-2 text-sm font-medium transition ${cls}`}
              >
                {item.label}
              </Link>
            );
          })}
          <Link href="/downloads/" className="vortex-btn ml-2 text-xs">
            Get ISO
          </Link>
        </nav>

        <button
          type="button"
          className="rounded-lg p-2 text-slate-400 md:hidden"
          onClick={() => setOpen(!open)}
          aria-label="Toggle menu"
        >
          {open ? <X size={22} /> : <Menu size={22} />}
        </button>
      </div>

      {open && (
        <nav className="border-t border-vortex-border px-4 py-4 md:hidden">
          {NAV.map((item) =>
            item.external ? (
              <a
                key={item.href}
                href={item.href}
                className="block rounded-lg px-3 py-2 text-sm text-slate-300"
              >
                {item.label}
              </a>
            ) : (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                className="block rounded-lg px-3 py-2 text-sm text-slate-300"
              >
                {item.label}
              </Link>
            )
          )}
        </nav>
      )}
    </header>
  );
}
