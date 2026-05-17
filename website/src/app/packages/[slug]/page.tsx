import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft, ExternalLink } from "lucide-react";
import { getAllPackages, getPackageBySlug } from "@/lib/packages";

type Props = { params: Promise<{ slug: string }> };

/** Pre-render packages in chunks; full list synced from packages.x86_64 */
export function generateStaticParams() {
  return getAllPackages().map((p) => ({ slug: p.slug }));
}

export const dynamicParams = false;

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const pkg = getPackageBySlug(slug);
  if (!pkg) return { title: "Package not found" };
  return {
    title: pkg.name,
    description: pkg.summary,
  };
}

function renderDetail(detail: string) {
  const parts = detail.split(/\*\*(.+?)\*\*/g);
  return parts.map((part, i) =>
    i % 2 === 1 ? (
      <strong key={i} className="text-white">
        {part}
      </strong>
    ) : (
      <span key={i}>{part}</span>
    )
  );
}

export default async function PackageDetailPage({ params }: Props) {
  const { slug } = await params;
  const pkg = getPackageBySlug(slug);
  if (!pkg) notFound();

  return (
    <div className="vortex-container py-12 md:py-16">
      <Link
        href="/packages/"
        className="inline-flex items-center gap-1 text-sm text-slate-400 hover:text-cyan-400"
      >
        <ChevronLeft size={16} /> Package index
      </Link>

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <code className="text-2xl font-bold text-cyan-300">{pkg.name}</code>
        <Link
          href={`/packages/category/${pkg.category}/`}
          className="rounded-full border border-vortex-border bg-vortex-card px-3 py-1 text-xs text-slate-400 hover:text-cyan-300"
        >
          {pkg.categoryLabel}
        </Link>
      </div>

      <p className="mt-4 text-lg text-slate-300">{pkg.summary}</p>

      <article className="prose-vortex mt-8 max-w-3xl">
        <h2>Overview</h2>
        <p>{renderDetail(pkg.detail)}</p>

        <h2>Common use cases</h2>
        <ul>
          {pkg.useCases.map((u) => (
            <li key={u}>{u}</li>
          ))}
        </ul>

        <h2>On a running system</h2>
        <p>
          Query installed version:{" "}
          <code>pacman -Qi {pkg.name}</code>
          <br />
          List files: <code>pacman -Ql {pkg.name}</code>
        </p>
      </article>

      <a
        href={pkg.archWiki}
        target="_blank"
        rel="noopener noreferrer"
        className="vortex-btn-outline mt-8"
      >
        <ExternalLink size={16} /> Arch Linux package search
      </a>
    </div>
  );
}
