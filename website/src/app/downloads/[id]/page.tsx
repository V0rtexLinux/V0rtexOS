import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { DOWNLOAD_VARIANTS, getVariant } from "@/data/download-variants";
import { DownloadVariantIcon } from "@/components/DownloadVariantIcon";
import { ChevronLeft, Download } from "lucide-react";

type Props = { params: Promise<{ id: string }> };

export function generateStaticParams() {
  return DOWNLOAD_VARIANTS.map((v) => ({ id: v.id }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const variant = getVariant(id);
  if (!variant) return { title: "Download not found" };
  return {
    title: `${variant.title} — Download`,
    description: variant.description,
  };
}

const GITHUB_RELEASES =
  "https://github.com/V0rtexLinux/V0rtexOS/releases/latest";

export default async function DownloadVariantPage({ params }: Props) {
  const { id } = await params;
  const variant = getVariant(id);
  if (!variant) notFound();

  return (
    <div className="vortex-container py-12 md:py-16">
      <Link
        href="/downloads/"
        className="inline-flex items-center gap-1 text-sm text-slate-400 hover:text-cyan-400"
      >
        <ChevronLeft size={16} /> All downloads
      </Link>

      <div className="mt-6 flex items-start gap-4">
        <DownloadVariantIcon name={variant.icon} size={40} />
        <div>
          <h1 className="text-3xl font-bold text-white">{variant.title}</h1>
          <p className="mt-1 text-cyan-400">{variant.tagline}</p>
        </div>
      </div>

      <p className="mt-6 max-w-3xl text-slate-300">{variant.description}</p>

      <div className="mt-8 flex flex-wrap gap-4">
        <a href={GITHUB_RELEASES} className="vortex-btn" target="_blank" rel="noopener noreferrer">
          <Download size={18} /> Get ISO
        </a>
        <div className="vortex-card px-4 py-2 text-sm">
          <span className="text-slate-500">File: </span>
          <code className="text-cyan-300">{variant.isoFile}</code>
          <span className="ml-3 text-slate-500">Size: {variant.size}</span>
        </div>
      </div>

      <div className="mt-12 grid gap-8 lg:grid-cols-2">
        <section className="vortex-card p-6">
          <h2 className="text-lg font-semibold text-white">Requirements</h2>
          <ul className="mt-4 space-y-2 text-sm text-slate-300">
            {variant.requirements.map((r) => (
              <li key={r} className="flex gap-2">
                <span className="text-cyan-500">•</span> {r}
              </li>
            ))}
          </ul>
        </section>

        <section className="vortex-card p-6">
          <h2 className="text-lg font-semibold text-white">Boot modes</h2>
          <ul className="mt-4 flex flex-wrap gap-2">
            {variant.boot.map((b) => (
              <li
                key={b}
                className="rounded-full border border-vortex-border bg-vortex-surface px-3 py-1 text-xs text-slate-300"
              >
                {b}
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="mt-8 vortex-card p-6">
        <h2 className="text-lg font-semibold text-white">Installation steps</h2>
        <ol className="mt-4 space-y-4">
          {variant.steps.map((step, i) => (
            <li key={step} className="flex gap-4 text-sm text-slate-300">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-cyan-500/20 text-xs font-bold text-cyan-300">
                {i + 1}
              </span>
              {step}
            </li>
          ))}
        </ol>
      </section>

      {variant.notes && variant.notes.length > 0 && (
        <section className="mt-8 rounded-xl border border-amber-500/30 bg-amber-500/5 p-6">
          <h2 className="text-lg font-semibold text-amber-200">Notes</h2>
          <ul className="mt-3 space-y-2 text-sm text-amber-100/80">
            {variant.notes.map((n) => (
              <li key={n}>• {n}</li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
