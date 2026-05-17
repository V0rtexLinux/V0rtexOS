import type { Metadata } from "next";
import Link from "next/link";
import { DOWNLOAD_VARIANTS } from "@/data/download-variants";
import { DownloadVariantIcon } from "@/components/DownloadVariantIcon";
import { ArrowRight, FileCheck } from "lucide-react";

export const metadata: Metadata = {
  title: "Downloads",
  description:
    "Download V0rtexOS for bare metal, virtual machines, USB live boot, SD cards, PXE, and more.",
};

const GITHUB_RELEASES =
  "https://github.com/V0rtexLinux/V0rtexOS/releases/latest";

export default function DownloadsPage() {
  return (
    <div className="vortex-container py-12 md:py-16">
      <div className="max-w-3xl">
        <h1 className="text-3xl font-bold text-white md:text-4xl">Downloads</h1>
        <p className="mt-4 text-slate-400">
          One ISO — multiple boot paths. Choose the guide that matches how you
          deploy V0rtexOS. Always verify SHA256 checksums before booting.
        </p>
      </div>

      <div className="mt-8 vortex-card flex flex-col gap-4 border-cyan-500/20 bg-cyan-500/5 p-6 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-start gap-3">
          <FileCheck className="shrink-0 text-cyan-400" size={28} />
          <div>
            <p className="font-semibold text-white">Latest release</p>
            <p className="mt-1 text-sm text-slate-400">
              ISO builds are published on GitHub Actions. Check releases for
              checksums and artifacts.
            </p>
          </div>
        </div>
        <a href={GITHUB_RELEASES} className="vortex-btn shrink-0" target="_blank" rel="noopener noreferrer">
          GitHub Releases
        </a>
      </div>

      <div className="mt-12 grid gap-6 md:grid-cols-2">
        {DOWNLOAD_VARIANTS.map((variant) => (
          <Link
            key={variant.id}
            href={`/downloads/${variant.id}/`}
            className={`vortex-card group relative block p-6 ${
              variant.featured ? "ring-1 ring-cyan-500/30" : ""
            }`}
          >
            {variant.featured && (
              <span className="absolute right-4 top-4 rounded-full bg-cyan-500/20 px-2 py-0.5 text-[10px] font-semibold uppercase text-cyan-300">
                Popular
              </span>
            )}
            <DownloadVariantIcon name={variant.icon} size={32} />
            <h2 className="mt-4 text-lg font-semibold text-white group-hover:text-cyan-300">
              {variant.title}
            </h2>
            <p className="mt-1 text-sm text-cyan-400/80">{variant.tagline}</p>
            <p className="mt-3 line-clamp-2 text-sm text-slate-400">
              {variant.description}
            </p>
            <span className="mt-4 inline-flex items-center gap-1 text-sm font-medium text-cyan-400">
              Read guide <ArrowRight size={16} />
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
