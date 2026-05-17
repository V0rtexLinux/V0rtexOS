#!/usr/bin/env node
/**
 * Parses aeternus-os/archiso/packages.x86_64 and emits src/data/packages.json
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const PACKAGES_FILE = path.join(
  ROOT,
  "..",
  "aeternus-os",
  "archiso",
  "packages.x86_64"
);
const OUT = path.join(ROOT, "src", "data", "packages.json");

const CURATED = {
  "linux-hardened": {
    summary: "Hardened Linux kernel with security patches and reduced attack surface.",
    detail:
      "V0rtexOS ships the Arch linux-hardened kernel with additional sysctl and module blacklists. It prioritizes security mitigations (PTI, slab hardening) over maximum throughput.",
    useCases: ["Live ISO", "Penetration testing host", "Privacy-focused desktop"],
  },
  tor: {
    summary: "Anonymizing overlay network for TCP traffic routing.",
    detail:
      "Tor integrates with Ghost Protocol to route traffic through the Tor network. Used for anonymous research, C2 simulation in lab environments, and privacy-preserving reconnaissance.",
    useCases: ["Anonymous browsing", "Onion services testing", "Traffic obfuscation"],
  },
  nmap: {
    summary: "Network discovery and security auditing scanner.",
    detail:
      "Industry-standard port scanner for host discovery, service/version detection, and scriptable NSE modules. Essential for network mapping during assessments.",
    useCases: ["Port scanning", "OS fingerprinting", "Vulnerability scripts"],
  },
  "i3-wm": {
    summary: "Tiling window manager — default desktop of V0rtexOS.",
    detail:
      "Lightweight, keyboard-driven WM paired with picom compositor, custom Cairo panels, and rofi launcher. Designed for fast context switching during security workflows.",
    useCases: ["Daily driver WM", "Multi-terminal layouts", "Low GPU usage"],
  },
  firefox: {
    summary: "Privacy-oriented web browser with hardened defaults.",
    detail:
      "Primary browser for web app testing, Burp proxying, and documentation. Configured for dark theme integration with the V0rtex desktop.",
    useCases: ["Web testing", "Documentation", "Proxy interception"],
  },
  apparmor: {
    summary: "Mandatory access control framework for Linux.",
    detail:
      "Restricts program capabilities with profiles. V0rtexOS enables AppArmor in GRUB cmdline and ships profiles for key tools like aet-scan.",
    useCases: ["MAC enforcement", "Container-less sandboxing", "Compliance"],
  },
  "wireguard-tools": {
    summary: "Modern VPN tunnel configuration utilities.",
    detail:
      "Used with Ghost Protocol and NetworkManager for fast, cryptographic VPN tunnels during engagements or privacy routing.",
    useCases: ["VPN tunnels", "Lab pivoting", "Encrypted egress"],
  },
  "python-scapy": {
    summary: "Python packet manipulation library for network scripting.",
    detail:
      "Craft, send, sniff, and dissect packets programmatically. Foundation for custom network tools and protocol fuzzing scripts.",
    useCases: ["Packet crafting", "Custom probes", "Protocol research"],
  },
};

const CATEGORY_META = {
  kernel: {
    label: "Kernel & Firmware",
    description: "Hardened kernel, initramfs tooling, and device firmware.",
  },
  base: {
    label: "Base System",
    description: "Core GNU/Linux userspace from Arch base meta-package.",
  },
  boot: {
    label: "Boot & Live Media",
    description: "Bootloaders, Plymouth splash, and memory testing.",
  },
  "crypto-disk": {
    label: "Encryption & Storage",
    description: "Disk encryption, partitioning, and filesystem tools.",
  },
  network: {
    label: "Networking",
    description: "Connectivity, firewalls, capture, and scanning foundations.",
  },
  anonymity: {
    label: "Anonymity & Proxy",
    description: "Tor, proxies, DNS privacy, and traffic obfuscation.",
  },
  "shell-terminal": {
    label: "Shell & Terminal",
    description: "Shells, multiplexers, editors, and CLI productivity.",
  },
  display: {
    label: "Display & Graphics",
    description: "Xorg stack, drivers, compositor, and screenshots.",
  },
  "window-manager": {
    label: "Desktop Environment",
    description: "i3 ecosystem, bars, notifications, and theming.",
  },
  fonts: { label: "Fonts", description: "Typography for terminal and UI." },
  apps: {
    label: "Applications",
    description: "File manager, media, calculator, and IDE utilities.",
  },
  "security-hardening": {
    label: "Security & Hardening",
    description: "MAC, sandboxes, audit, and host intrusion prevention.",
  },
  development: {
    label: "Development",
    description: "Compilers, runtimes, and version control.",
  },
  python: {
    label: "Python Libraries",
    description: "Security automation and web tooling in Python.",
  },
  utilities: {
    label: "System Utilities",
    description: "Monitoring, archiving, hardware info, and misc tools.",
  },
  other: { label: "Other", description: "Additional packages in the image." },
};

function slugify(name) {
  return name.replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "").toLowerCase();
}

function guessSummary(name, category) {
  if (CURATED[name]) return CURATED[name].summary;
  const readable = name.replace(/^python-/, "").replace(/-/g, " ");
  const templates = {
    kernel: `Kernel and boot support component: ${readable}.`,
    network: `Networking tool for connectivity, capture, or analysis: ${readable}.`,
    anonymity: `Privacy and proxy-related component: ${readable}.`,
    display: `Display server or graphical utility: ${readable}.`,
    "security-hardening": `Security hardening or access control component: ${readable}.`,
    python: `Python module for security automation and scripting: ${readable}.`,
    development: `Development toolchain package: ${readable}.`,
  };
  return (
    templates[category] ||
    `Arch package included in the V0rtexOS live image: ${readable}.`
  );
}

function guessDetail(name, category) {
  if (CURATED[name]) return CURATED[name].detail;
  return `**${name}** is part of the official V0rtexOS package manifest (category: ${CATEGORY_META[category]?.label || category}). It is installed from Arch Linux and BlackArch repositories during the ISO build. For upstream documentation, see the Arch Linux package page or man pages on a running system (\`pacman -Qi ${name}\`).`;
}

function parsePackagesFile(content) {
  let category = "other";
  const packages = [];

  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      if (trimmed.includes("KERNEL")) category = "kernel";
      else if (trimmed.includes("BASE DO SISTEMA")) category = "base";
      else if (trimmed.includes("BOOT")) category = "boot";
      else if (trimmed.includes("CRIPTOGRAFIA")) category = "crypto-disk";
      else if (trimmed.includes("REDE")) category = "network";
      else if (trimmed.includes("ANONIMATO")) category = "anonymity";
      else if (trimmed.includes("SHELL")) category = "shell-terminal";
      else if (trimmed.includes("X.ORG") || trimmed.includes("Drivers"))
        category = "display";
      else if (trimmed.includes("WINDOW MANAGER")) category = "window-manager";
      else if (trimmed.includes("FONTES")) category = "fonts";
      else if (trimmed.includes("APPS ESSENCIAIS")) category = "apps";
      else if (trimmed.includes("SEGURANÇA BASE")) category = "security-hardening";
      else if (trimmed.includes("DESENVOLVIMENTO")) category = "development";
      else if (trimmed.includes("PYTHON")) category = "python";
      else if (trimmed.includes("UTILITÁRIOS")) category = "utilities";
      continue;
    }
    const name = trimmed.split(/\s+/)[0];
    if (!name || name.startsWith("#")) continue;

    packages.push({
      name,
      slug: slugify(name),
      category,
      categoryLabel: CATEGORY_META[category]?.label || category,
      summary: guessSummary(name, category),
      detail: guessDetail(name, category),
      useCases: CURATED[name]?.useCases || [
        "Included in live ISO",
        "Available after boot",
      ],
      archWiki: `https://archlinux.org/packages/?q=${encodeURIComponent(name)}`,
    });
  }

  return packages;
}

const content = fs.readFileSync(PACKAGES_FILE, "utf8");
const packages = parsePackagesFile(content);
const categories = Object.entries(CATEGORY_META).map(([id, meta]) => ({
  id,
  ...meta,
  count: packages.filter((p) => p.category === id).length,
}));

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(
  OUT,
  JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      total: packages.length,
      categories,
      packages,
    },
    null,
    2
  )
);

console.log(`Generated ${packages.length} packages → ${OUT}`);
