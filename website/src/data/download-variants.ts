export type DownloadVariant = {
  id: string;
  title: string;
  tagline: string;
  description: string;
  icon: string;
  isoFile: string;
  size: string;
  sha256?: string;
  boot: string[];
  requirements: string[];
  steps: string[];
  notes?: string[];
  featured?: boolean;
};

export const DOWNLOAD_VARIANTS: DownloadVariant[] = [
  {
    id: "standard-live",
    title: "Standard Live ISO",
    tagline: "Default image for most users",
    description:
      "The primary V0rtexOS image with hardened kernel, i3 desktop, Ghost Protocol, and the full base toolset. Boots from USB, DVD, or VM optical drive with UEFI and legacy BIOS support.",
    icon: "disc",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso",
    size: "~4–6 GB",
    boot: ["UEFI", "Legacy BIOS", "Secure Boot (with keys)"],
    requirements: [
      "x86_64 CPU with 64-bit support",
      "4 GB RAM minimum (8 GB recommended)",
      "8 GB USB drive or any DVD drive",
    ],
    steps: [
      "Download the ISO and verify the SHA256 checksum",
      "Flash with Rufus, balenaEtcher, or dd: dd if=*.iso of=/dev/sdX bs=4M status=progress",
      "Boot from USB — select V0rtexOS in GRUB/syslinux menu",
      "Default credentials: root / v0rtex (change immediately in production)",
    ],
    featured: true,
  },
  {
    id: "bare-metal",
    title: "Bare Metal Install",
    tagline: "Physical laptops and workstations",
    description:
      "Same ISO as the live image, used to install or run directly on physical hardware. Optimized for DRM/KMS graphics on Intel, AMD, and modern NVIDIA (nouveau/modesetting).",
    icon: "cpu",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso",
    size: "~4–6 GB",
    boot: ["UEFI GPT", "Legacy MBR"],
    requirements: [
      "Physical machine with UEFI or BIOS",
      "Ethernet or Wi-Fi (Intel/ath9k well supported)",
      "Target disk for optional persistence overlay",
    ],
    steps: [
      "Boot live USB and verify networking with Ghost Protocol",
      "Use archinstall or manual partitioning for full disk install",
      "Optional: encrypted LVM with cryptsetup (pre-installed)",
      "Reboot and remove installation media",
    ],
    notes: [
      "Disable Fast Boot in firmware for reliable USB boot",
      "NVIDIA proprietary drivers: install post-boot from Arch repos if needed",
    ],
    featured: true,
  },
  {
    id: "virtual-machine",
    title: "Virtual Machine",
    tagline: "QEMU, VMware, VirtualBox, Hyper-V",
    description:
      "Designed for labs and training. Use virtio GPU/RNG/NET in QEMU for best performance. SPICE vdagent included for clipboard integration.",
    icon: "box",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso",
    size: "~4–6 GB",
    boot: ["UEFI recommended", "IDE/SATA optical"],
    requirements: [
      "Hypervisor: QEMU/KVM, VMware Workstation, VirtualBox 7+, or Hyper-V",
      "4 GB VM RAM, 2+ vCPUs",
      "40 GB virtual disk for persistence",
    ],
    steps: [
      "Attach ISO as bootable optical drive",
      "QEMU example: qemu-system-x86_64 -m 4096 -smp 4 -cdrom v0rtex-os*.iso -vga virtio",
      "Select V0rtexOS (VM/Fast Boot) menu entry for reduced mitigations in nested virt",
      "Install spice-vdagent guest tools run automatically on X session start",
    ],
    notes: [
      "Do not use nomodeset on default VM entry — virtio GPU needs KMS",
      "Use USB tablet device for proper mouse capture in QEMU",
    ],
    featured: true,
  },
  {
    id: "usb-live",
    title: "USB Live Boot",
    tagline: "Portable persistent sessions",
    description:
      "Boot a full desktop from USB with optional overlay persistence (cow_spacesize=4G kernel parameter). Ideal for engagements where you leave no trace on host disks.",
    icon: "usb",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso",
    size: "~4–6 GB",
    boot: ["USB 3.0+", "USB-C adapters"],
    requirements: [
      "USB 8 GB+ (16 GB for comfort with persistence)",
      "Host firmware USB boot enabled",
    ],
    steps: [
      "Flash ISO to USB (not partition copy — full disk image write)",
      "Boot USB — overlay stores changes in RAM+cow by default",
      "Run safe-off or amnesia before removal for memory hygiene",
    ],
    notes: [
      "Persistence is volatile unless you configure custom overlay on partition",
    ],
  },
  {
    id: "sd-card",
    title: "SD Card / microSD Live",
    tagline: "Small form-factor and ARM SBC adapters",
    description:
      "Same x86_64 ISO written to SD via USB adapters or SD slot on supported laptops. Useful for discrete media and hot-swappable lab images.",
    icon: "sd",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso",
    size: "~4–6 GB",
    boot: ["SD reader", "USB SD adapter"],
    requirements: [
      "x86_64 host (ISO is not ARM)",
      "SD card UHS-I 16 GB+ recommended",
      "Reliable adapter (cheap adapters cause I/O errors)",
    ],
    steps: [
      "Use dd or Etcher targeting the SD block device",
      "Label media physically — identical ISOs are easy to mix up",
      "Boot SD the same as USB in firmware boot menu",
    ],
    notes: [
      "Raspberry Pi and ARM boards require a different architecture — not supported by this ISO",
    ],
  },
  {
    id: "fast-vm",
    title: "Fast VM / Nested Virtualization",
    tagline: "Reduced mitigations for speed",
    description:
      "Syslinux/GRUB entry V0rtexOS (VM/Fast Boot) with mitigations=off for nested hypervisors and slow hosts. Trade security margins for responsiveness in training VMs.",
    icon: "zap",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso (menu: Fast Boot)",
    size: "~4–6 GB",
    boot: ["Same ISO — alternate boot entry"],
    requirements: ["Nested virtualization enabled", "Host hypervisor"],
    steps: [
      "At boot menu select V0rtexOS (VM/Fast Boot)",
      "Use only in isolated lab networks",
    ],
    notes: ["Not recommended for bare metal or internet-facing use"],
  },
  {
    id: "safe-vesa",
    title: "Safe Mode (VESA / nomodeset)",
    tagline: "When graphics fail to start",
    description:
      "Recovery entry with nomodeset for broken GPU drivers or legacy hardware. Xorg falls back to fbdev/vesa drivers.",
    icon: "shield",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso (menu: Safe/VESA)",
    size: "~4–6 GB",
    boot: ["BIOS syslinux Safe entry"],
    requirements: ["Use when standard boot shows black screen"],
    steps: [
      "Select V0rtexOS (Safe/VESA — no KMS) at syslinux menu",
      "After boot, diagnose with cat /tmp/xorg.log",
    ],
  },
  {
    id: "debug",
    title: "Debug / Verbose",
    tagline: "Troubleshooting and development",
    description:
      "Verbose kernel and systemd logging for diagnosing boot, networking, or Plymouth issues.",
    icon: "terminal",
    isoFile: "v0rtex-os-YYYY.MM.DD-x86_64.iso (menu: Debug)",
    size: "~4–6 GB",
    boot: ["Debug menu entry"],
    requirements: ["Serial or framebuffer console access"],
    steps: [
      "Boot Debug/Verbose entry",
      "Collect logs: journalctl -b, dmesg, /tmp/xorg.log",
    ],
  },
  {
    id: "netboot",
    title: "Network Boot (PXE/iPXE)",
    tagline: "Lab-wide deployment",
    description:
      "Serve the ISO root via HTTP/NFS in your lab. Requires manual PXE setup — documented for advanced users rolling corporate training environments.",
    icon: "network",
    isoFile: "Extracted arch/ tree from ISO",
    size: "Varies",
    boot: ["PXE", "iPXE"],
    requirements: ["DHCP server", "TFTP/HTTP mirror", "Arch netboot docs"],
    steps: [
      "Extract ISO or sync build artifacts to netboot server",
      "Configure iPXE chain per Arch wiki netboot guidelines",
      "Point kernel and initramfs paths to linux-hardened artifacts",
    ],
    notes: ["Official PXE profile coming in a future release"],
  },
  {
    id: "tools-only",
    title: "Post-Boot Tool Expansion",
    tagline: "Not an ISO — install-tools manifest",
    description:
      "100+ offensive security tools (Metasploit, sqlmap, BloodHound, etc.) are not in the base ISO to save space. Install after boot with install-tools.sh from BlackArch and GitHub.",
    icon: "package",
    isoFile: "N/A — run inside live system",
    size: "10–30 GB additional",
    boot: ["Requires running V0rtexOS"],
    requirements: ["Network access", "Disk or overlay space"],
    steps: [
      "Boot any V0rtexOS image",
      "sudo install-tools all",
      "Or category: recon, exploit, wireless, web, post",
    ],
    featured: true,
  },
];

export function getVariant(id: string) {
  return DOWNLOAD_VARIANTS.find((v) => v.id === id);
}
