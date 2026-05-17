import Link from "next/link";

export function Footer() {
  return (
    <footer className="mt-auto border-t border-vortex-border bg-vortex-surface/50">
      <div className="vortex-container grid gap-8 py-12 md:grid-cols-4">
        <div className="md:col-span-2">
          <p className="text-lg font-bold">
            V0rtex<span className="text-cyan-400">OS</span>
          </p>
          <p className="mt-2 max-w-md text-sm text-slate-400">
            Grey Hat Linux — hardened kernel, privacy routing, and a security-focused
            desktop built on Arch Linux and BlackArch tooling.
          </p>
        </div>
        <div>
          <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-slate-500">
            Project
          </p>
          <ul className="space-y-2 text-sm text-slate-400">
            <li>
              <Link href="/downloads/" className="hover:text-cyan-400">
                Downloads
              </Link>
            </li>
            <li>
              <Link href="/packages/" className="hover:text-cyan-400">
                Package index
              </Link>
            </li>
            <li>
              <Link href="/docs/" className="hover:text-cyan-400">
                Documentation
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-slate-500">
            Community
          </p>
          <ul className="space-y-2 text-sm text-slate-400">
            <li>
              <a
                href="https://github.com/V0rtexLinux/V0rtexOS"
                className="hover:text-cyan-400"
              >
                GitHub
              </a>
            </li>
            <li>
              <a
                href="https://github.com/V0rtexLinux/V0rtexOS/issues"
                className="hover:text-cyan-400"
              >
                Issues
              </a>
            </li>
          </ul>
        </div>
      </div>
      <div className="border-t border-vortex-border py-4 text-center text-xs text-slate-500">
        Use responsibly. Authorized testing only. © {new Date().getFullYear()} V0rtexOS.
      </div>
    </footer>
  );
}
