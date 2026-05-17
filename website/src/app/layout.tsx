import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "V0rtexOS — Grey Hat Linux for Security Professionals",
    template: "%s | V0rtexOS",
  },
  description:
    "Hardened Arch-based Linux for penetration testing, privacy, and security research. Live ISO, VM images, and 300+ documented packages.",
  keywords: [
    "V0rtexOS",
    "security linux",
    "penetration testing",
    "hardened kernel",
    "Arch Linux",
    "BlackArch",
  ],
  openGraph: {
    title: "V0rtexOS",
    description: "Grey Hat Linux — Hardened. Anonymous. Ready.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} flex min-h-screen flex-col font-sans`}
      >
        <Header />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
