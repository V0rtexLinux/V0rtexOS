# V0rtexOS Website

Marketing and documentation site for V0rtexOS (English).

## Pages

- **Home** — product overview and features
- **Downloads** — 10 deployment guides (VM, bare metal, USB, SD, PXE, safe mode, …)
- **Packages** — full ISO package catalog with individual pages per package
- **Documentation** — quick start and links

## Develop

```bash
cd website
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Build static site

```bash
npm run build
```

Output: `out/` — deploy to GitHub Pages, Cloudflare Pages, or Netlify.

## Regenerate package index

After editing `aeternus-os/archiso/packages.x86_64`:

```bash
npm run generate
```
