# Aeternus OS — X11 GUI (C/Cairo)

GUI nativa em C puro usando Xlib + Cairo. Sem Python, sem web.

## Componentes

| Programa            | Fonte                        | Função                                    |
|---------------------|------------------------------|-------------------------------------------|
| `aeternus-splash`   | `splash/aeternus-splash.c`   | Splash screen animado (swipe animations)  |
| `aeternus-panel`    | `panel/aeternus-panel.c`     | Barra de status/workspaces (top bar)      |
| `gen-wallpaper`     | `wallpaper/gen-wallpaper.c`  | Gera o wallpaper PNG (hex grid, dark)     |

## Paleta

- **Fundo**: `#000000` (preto puro)
- **Primária**: `#ffffff` (branco)
- **Secundária**: `#888888` (cinza)
- **Dim**: `#222222` (escuro)

## Animações do Splash

1. **0.10s** — Barras horizontais deslizam (esquerda / direita)
2. **0.45s** — "AETERNUS" entra deslizando da esquerda
3. **0.65s** — "OS" entra deslizando da direita
4. **0.85s** — Tagline fade-in
5. **1.20s** — Hexagonal grid revela progressivamente
6. **1.80s** — Barra de loading preenche
7. **3.20s** — Fade-out total → desktop

## Compilar

```bash
cd gui/
make all        # compila tudo
make install    # instala em /usr/local/
```

## Dependências (pacotes Arch)

```
cairo libxrender libx11 gcc make
```

## Boot sequence

```
login → startx → .xinitrc → aeternus-splash → [wallpaper, picom, panel] → i3wm
```
