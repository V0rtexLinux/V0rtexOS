import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        vortex: {
          bg: "#06080c",
          surface: "#0c1018",
          card: "#111827",
          border: "#1e293b",
          muted: "#64748b",
          text: "#e2e8f0",
          accent: "#22d3ee",
          accent2: "#a78bfa",
          danger: "#f43f5e",
          success: "#34d399",
        },
      },
      fontFamily: {
        sans: ["var(--font-geist-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-geist-mono)", "JetBrains Mono", "monospace"],
      },
      backgroundImage: {
        "grid-pattern":
          "linear-gradient(to right, rgba(34,211,238,0.04) 1px, transparent 1px), linear-gradient(to bottom, rgba(34,211,238,0.04) 1px, transparent 1px)",
      },
    },
  },
  plugins: [],
};

export default config;
