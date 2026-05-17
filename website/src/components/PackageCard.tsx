import Link from "next/link";
import type { PackageEntry } from "@/lib/packages";

export function PackageCard({ pkg }: { pkg: PackageEntry }) {
  return (
    <Link
      href={`/packages/${pkg.slug}/`}
      className="vortex-card group block p-4"
    >
      <div className="flex items-start justify-between gap-2">
        <code className="font-mono text-sm text-cyan-300 group-hover:text-cyan-200">
          {pkg.name}
        </code>
        <span className="shrink-0 rounded-full bg-vortex-surface px-2 py-0.5 text-[10px] uppercase tracking-wide text-slate-500">
          {pkg.categoryLabel}
        </span>
      </div>
      <p className="mt-2 line-clamp-2 text-sm text-slate-400">{pkg.summary}</p>
    </Link>
  );
}
