import packagesData from "@/data/packages.json";

export type PackageEntry = {
  name: string;
  slug: string;
  category: string;
  categoryLabel: string;
  summary: string;
  detail: string;
  useCases: string[];
  archWiki: string;
};

export type PackagesManifest = {
  generatedAt: string;
  total: number;
  categories: { id: string; label: string; description: string; count: number }[];
  packages: PackageEntry[];
};

const manifest = packagesData as PackagesManifest;

export function getAllPackages(): PackageEntry[] {
  return manifest.packages;
}

export function getPackageBySlug(slug: string): PackageEntry | undefined {
  return manifest.packages.find((p) => p.slug === slug);
}

export function getCategories() {
  return manifest.categories.filter((c) => c.count > 0);
}

export function getPackagesByCategory(categoryId: string) {
  return manifest.packages.filter((p) => p.category === categoryId);
}

export function getManifestMeta() {
  return { total: manifest.total, generatedAt: manifest.generatedAt };
}
