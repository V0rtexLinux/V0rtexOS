import Link from "next/link";
import {
  Shield,
  Ghost,
  Terminal,
  Download,
  Package,
  Lock,
  Zap,
  Eye,
} from "lucide-react";
import { getManifestMeta } from "@/lib/packages";

export default function HomePage() {
  const { total } = getManifestMeta();

  return (
    <>
      <section className="relative overflow-hidden border-b border-vortex-border">
        <div className="absolute inset-0 bg-grid-pattern bg-[length:48px_48px] opacity-60" />
        <div className="absolute inset-0 bg-gradient-to-b from-cyan-500/5 via-transparent to-vortex-bg" />
        <div className="vortex-container relative py-24 md:py-32">
          <p className="mb-4 inline-flex items-center gap-2 rounded-full border border-cyan-500/30 bg-cyan-500/10 px-3 py-1 text-xs font-medium text-cyan-300">
            <Zap size={14} /> linux-hardened · Ghost Protocol · i3 desktop
          </p>
          <h1 className="max-w-3xl text-4xl font-bold tracking-tight text-white md:text-6xl">
            Grey Hat Linux for{" "}
            <span className="bg-gradient-to-r from-cyan-400 to-violet-400 bg-clip-text text-transparent">
              security professionals
            </span>
          </h1>
          <p className="mt-6 max-w-2xl text-lg text-slate-400">
            V0rtexOS is a hardened, live-bootable distribution built on Arch Linux
            with Tor routing, AppArmor, and a curated offensive-security stack.
            Boot from USB, SD card, bare metal, or any hypervisor.
          </p>
          <div className="mt-10 flex flex-wrap gap-4">
            <Link href="/downloads/" className="vortex-btn">
              <Download size={18} /> Download ISO
            </Link>
            <Link href="/packages/" className="vortex-btn-outline">
              <Package size={18} /> Browse {total} packages
            </Link>
          </div>
        </div>
      </section>

      <section className="vortex-container py-20">
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {[
            { label: "Base packages", value: `${total}+`, sub: "Documented in catalog" },
            { label: "Post-boot tools", value: "100+", sub: "via install-tools" },
            { label: "Boot targets", value: "10", sub: "VM · USB · metal · PXE" },
            { label: "Kernel", value: "hardened", sub: "Security-first patches" },
          ].map((stat) => (
            <div key={stat.label} className="vortex-card p-6 text-center">
              <p className="text-3xl font-bold text-cyan-400">{stat.value}</p>
              <p className="mt-1 font-medium text-white">{stat.label}</p>
              <p className="text-xs text-slate-500">{stat.sub}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-y border-vortex-border bg-vortex-surface/30 py-20">
        <div className="vortex-container">
          <h2 className="text-center text-2xl font-bold text-white md:text-3xl">
            Built for real engagements
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-center text-slate-400">
            From live USB boots to nested VMs — every surface is documented with
            checksums, requirements, and hardening notes.
          </p>
          <div className="mt-12 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {[
              {
                icon: Shield,
                title: "Hardened by default",
                text: "linux-hardened, sysctl lockdown, module blacklists, and AppArmor profiles on critical tools.",
              },
              {
                icon: Ghost,
                title: "Ghost Protocol",
                text: "VPN + Tor kill switch blocks leaks when tunnels drop. Privacy routing out of the box.",
              },
              {
                icon: Terminal,
                title: "Operator desktop",
                text: "i3wm, Cairo panels, rofi, Alacritty, and zsh — tuned for terminal-heavy workflows.",
              },
              {
                icon: Eye,
                title: "Amnesia mode",
                text: "safe-off and amnesia scripts scrub RAM and logs before shutdown on live sessions.",
              },
              {
                icon: Lock,
                title: "Encryption ready",
                text: "cryptsetup, LVM, and multiple filesystem tools for full-disk encrypted installs.",
              },
              {
                icon: Package,
                title: "Expandable arsenal",
                text: "Base ISO stays lean; install Metasploit, sqlmap, BloodHound, and more post-boot.",
              },
            ].map(({ icon: Icon, title, text }) => (
              <div key={title} className="vortex-card p-6">
                <Icon className="mb-4 text-cyan-400" size={28} />
                <h3 className="font-semibold text-white">{title}</h3>
                <p className="mt-2 text-sm text-slate-400">{text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="vortex-container py-20 text-center">
        <h2 className="text-2xl font-bold text-white">Ready to spin up a lab?</h2>
        <p className="mt-3 text-slate-400">
          Pick your deployment target — we document every boot path.
        </p>
        <Link href="/downloads/" className="vortex-btn mt-8">
          View all download options
        </Link>
      </section>
    </>
  );
}
