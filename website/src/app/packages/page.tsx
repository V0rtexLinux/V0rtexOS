import type { Metadata } from "next";
import Link from "next/link";
import { PackagesBrowser } from "@/components/PackagesBrowser";
import {
  getAllPackages,
  getCategories,
  getManifestMeta,
} from "@/lib/packages";

export const metadata: Metadata = {
  title: "Packages",
  description:
    "Complete catalog of packages shipped in the V0rtexOS live image — every tool documented.",
};

export default function PackagesPage() {
  const packages = getAllPackages();
  const categories = getCategories();
  const { total, generatedAt } = getManifestMeta();

  return (
    <div className="vortex-container py-12 md:py-16">
      <div className="max-w-3xl">
        <h1 className="text-3xl font-bold text-white md:text-4xl">Package catalog</h1>
        <p className="mt-4 text-slate-400">
          Every package in the base ISO — {total} entries synced from{" "}
          <code className="text-cyan-400">archiso/packages.x86_64</code>. Click any
          package for details, use cases, and Arch Linux references. Post-boot tools
          from <code className="text-cyan-400">install-tools.sh</code> are listed in
          the{" "}
          <Link href="/downloads/tools-only/" className="text-cyan-400 hover:underline">
            tools expansion
          </Link>{" "}
          guide.
        </p>
        <p className="mt-2 text-xs text-slate-600">
          Index generated: {new Date(generatedAt).toLocaleDateString("en-US")}
        </p>
      </div>

      <div className="mt-10 flex flex-wrap gap-2">
        {categories.map((c) => (
          <Link
            key={c.id}
            href={`/packages/category/${c.id}/`}
            className="rounded-full border border-vortex-border bg-vortex-card px-3 py-1 text-xs text-slate-400 transition hover:border-cyan-500/40 hover:text-cyan-300"
          >
            {c.label} ({c.count})
          </Link>
        ))}
      </div>

      <div className="mt-10">
        <PackagesBrowser packages={packages} categories={categories} />
      </div>
    </div>
  );
}
