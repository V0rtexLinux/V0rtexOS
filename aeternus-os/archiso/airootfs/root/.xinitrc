#!/bin/sh
# V0rtexOS — xinitrc
# Boot sequence: splash → panel → i3wm

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=i3

# Log file para diagnóstico
XLOG=/tmp/v0rtex-session.log
exec > "$XLOG" 2>&1

echo "[xinitrc] $(date) — iniciando sessão X"

# Cursor
xsetroot -cursor_name left_ptr 2>/dev/null || true

# ── Splash screen (blocks until animation finishes) ──────────────────────────
if command -v aeternus-splash >/dev/null 2>&1; then
    echo "[xinitrc] iniciando splash screen"
    aeternus-splash
fi

# ── Wallpaper ─────────────────────────────────────────────────────────────────
echo "[xinitrc] configurando wallpaper"
if [ -f /usr/local/share/v0rtex/wallpaper.png ]; then
    feh --bg-scale /usr/local/share/v0rtex/wallpaper.png &
elif [ -f ~/.config/i3/wallpaper.png ]; then
    feh --bg-scale ~/.config/i3/wallpaper.png &
else
    xsetroot -solid "#000000" 2>/dev/null || true
fi

# ── Compositor ────────────────────────────────────────────────────────────────
echo "[xinitrc] iniciando picom"
if command -v picom >/dev/null 2>&1; then
    if [ -f ~/.config/picom/picom.conf ]; then
        picom --config ~/.config/picom/picom.conf -b 2>>/tmp/v0rtex-picom.log || \
            picom -b 2>>/tmp/v0rtex-picom.log &
    else
        picom -b 2>>/tmp/v0rtex-picom.log &
    fi
fi

# ── Desktop panel (top bar) ───────────────────────────────────────────────────
if command -v aeternus-panel >/dev/null 2>&1; then
    echo "[xinitrc] iniciando aeternus-panel"
    aeternus-panel &
fi

# ── Desktop taskbar (bottom bar) ──────────────────────────────────────────────
if command -v aeternus-taskbar >/dev/null 2>&1; then
    echo "[xinitrc] iniciando aeternus-taskbar"
    aeternus-taskbar &
fi

# ── Notifications ─────────────────────────────────────────────────────────────
dunst & 2>/dev/null || true

# ── Network tray ──────────────────────────────────────────────────────────────
nm-applet & 2>/dev/null || true

# ── Window manager ────────────────────────────────────────────────────────────
echo "[xinitrc] iniciando i3"
exec i3 2>>/tmp/v0rtex-i3.log
echo "[xinitrc] i3 encerrado com código $?"
