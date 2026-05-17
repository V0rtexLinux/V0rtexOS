import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { PackageCard } from "@/components/PackageCard";
import { getCategories, getPackagesByCategory } from "@/lib/packages";

type Props = { params: Promise<{ id: string }> };

export function generateStaticParams() {
  return getCategories().map((c) => ({ id: c.id }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const cat = getCategories().find((c) => c.id === id);
  if (!cat) return { title: "Category not found" };
  return {
    title: `${cat.label} packages`,
    description: cat.description,
  };
}

export default async function PackageCategoryPage({ params }: Props) {
  const { id } = await params;
  const cat = getCategories().find((c) => c.id === id);
  if (!cat) notFound();

  const packages = getPackagesByCategory(id);

  return (
    <div className="vortex-container py-12 md:py-16">
      <Link
        href="/packages/"
        className="inline-flex items-center gap-1 text-sm text-slate-400 hover:text-cyan-400"
      >
        <ChevronLeft size={16} /> All packages
      </Link>

      <h1 className="mt-6 text-3xl font-bold text-white">{cat.label}</h1>
      <p className="mt-2 max-w-2xl text-slate-400">{cat.description}</p>
      <p className="mt-2 text-sm text-slate-500">{packages.length} packages</p>

      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {packages.map((pkg) => (
          <PackageCard key={pkg.slug} pkg={pkg} />
        ))}
      </div>
    </div>
  );
}
