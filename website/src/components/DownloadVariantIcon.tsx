import {
  Box,
  Cpu,
  Disc,
  HardDrive,
  Network,
  Package,
  Shield,
  Terminal,
  Usb,
  Zap,
} from "lucide-react";

const ICONS: Record<string, React.ComponentType<{ className?: string; size?: number }>> = {
  disc: Disc,
  cpu: Cpu,
  box: Box,
  usb: Usb,
  sd: HardDrive,
  zap: Zap,
  shield: Shield,
  terminal: Terminal,
  network: Network,
  package: Package,
};

export function DownloadVariantIcon({
  name,
  size = 24,
  className = "text-cyan-400",
}: {
  name: string;
  size?: number;
  className?: string;
}) {
  const Icon = ICONS[name] || Disc;
  return <Icon size={size} className={className} />;
}
