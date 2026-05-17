import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Documentation",
  description: "Build, install, and operate V0rtexOS — quick start and references.",
};

export default function DocsPage() {
  return (
    <div className="vortex-container py-12 md:py-16">
      <h1 className="text-3xl font-bold text-white md:text-4xl">Documentation</h1>
      <p className="mt-4 max-w-2xl text-slate-400">
        Essential guides for building the ISO, first boot, and daily operations.
      </p>

      <div className="mt-12 grid gap-6 md:grid-cols-2">
        {[
          {
            title: "Build from source",
            body: "Requires Arch Linux or Docker/Podman. Run build.sh as root; output lands in release/.",
            href: "https://github.com/V0rtexLinux/V0rtexOS/blob/main/aeternus-os/INSTALL.md",
          },
          {
            title: "First boot",
            body: "Default login root@v0rtex on tty1. Xorg starts automatically. Ghost Protocol enables Tor routing.",
            href: "/downloads/standard-live/",
          },
          {
            title: "Install offensive tools",
            body: "sudo install-tools all — downloads 100+ tools from GitHub and BlackArch after live boot.",
            href: "/downloads/tools-only/",
          },
          {
            title: "Ghost Protocol",
            body: "VPN+Tor kill switch systemd service. Blocks clearnet leaks when tunnels fail.",
            href: "https://github.com/V0rtexLinux/V0rtexOS/tree/main/aeternus-os/ghost-protocol",
          },
          {
            title: "Amnesia shutdown",
            body: "safe-off or sudo amnesia --confirm wipes sensitive state before poweroff.",
            href: "https://github.com/V0rtexLinux/V0rtexOS/blob/main/aeternus-os/amnesia.sh",
          },
          {
            title: "Package catalog",
            body: "Full list of ISO packages with per-package documentation pages.",
            href: "/packages/",
          },
        ].map((doc) => (
          <Link key={doc.title} href={doc.href} className="vortex-card block p-6">
            <h2 className="font-semibold text-white">{doc.title}</h2>
            <p className="mt-2 text-sm text-slate-400">{doc.body}</p>
          </Link>
        ))}
      </div>

      <section className="mt-12 vortex-card p-6">
        <h2 className="text-lg font-semibold text-white">Quick commands</h2>
        <pre className="mt-4 overflow-x-auto rounded-lg bg-vortex-bg p-4 font-mono text-sm text-cyan-200">
{`# Build ISO (Arch host)
sudo bash aeternus-os/build.sh

# Flash USB
sudo dd if=release/v0rtex-os-*.iso of=/dev/sdX bs=4M status=progress

# After boot
sudo install-tools all
check-anon
sudo aet-scan -p vuln <target>
safe-off`}
        </pre>
      </section>
    </div>
  );
}
