"use client";

import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { PackageCard } from "@/components/PackageCard";
import type { PackageEntry } from "@/lib/packages";

type Category = { id: string; label: string; description: string; count: number };

export function PackagesBrowser({
  packages,
  categories,
}: {
  packages: PackageEntry[];
  categories: Category[];
}) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<string>("all");

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return packages.filter((p) => {
      if (category !== "all" && p.category !== category) return false;
      if (!q) return true;
      return (
        p.name.toLowerCase().includes(q) ||
        p.summary.toLowerCase().includes(q) ||
        p.categoryLabel.toLowerCase().includes(q)
      );
    });
  }, [packages, query, category]);

  return (
    <>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search
            className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500"
            size={18}
          />
          <input
            type="search"
            placeholder="Search packages…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="w-full rounded-lg border border-vortex-border bg-vortex-card py-2.5 pl-10 pr-4 text-sm text-white placeholder:text-slate-500 focus:border-cyan-500/50 focus:outline-none focus:ring-1 focus:ring-cyan-500/30"
          />
        </div>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="rounded-lg border border-vortex-border bg-vortex-card px-4 py-2.5 text-sm text-white focus:border-cyan-500/50 focus:outline-none"
        >
          <option value="all">All categories</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.label} ({c.count})
            </option>
          ))}
        </select>
      </div>

      <p className="mt-4 text-sm text-slate-500">
        Showing {filtered.length} of {packages.length} packages
      </p>

      <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {filtered.map((pkg) => (
          <PackageCard key={pkg.slug} pkg={pkg} />
        ))}
      </div>

      {filtered.length === 0 && (
        <p className="mt-12 text-center text-slate-500">No packages match your search.</p>
      )}
    </>
  );
}
