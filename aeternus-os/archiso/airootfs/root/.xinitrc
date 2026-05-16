#!/bin/sh
# V0rtexOS — xinitrc
# Boot sequence: splash → compositor → panel → i3wm

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=i3

# XAUTHORITY: deve estar definido antes de qualquer cliente X conectar
# startx normalmente define isso, mas garantimos aqui como fallback
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
touch "$XAUTHORITY" 2>/dev/null || true
chmod 600 "$XAUTHORITY" 2>/dev/null || true

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
touch "$XAUTHORITY"

# Log file para diagnóstico
XLOG=/tmp/v0rtex-session.log
exec >> "$XLOG" 2>&1

echo "[xinitrc] $(date) — sessão X iniciada (DISPLAY=$DISPLAY)"

# ── Cursor ────────────────────────────────────────────────────────────────────
xsetroot -cursor_name left_ptr 2>/dev/null || true
xsetroot -solid "#000000"     2>/dev/null || true

# ── Splash screen (blocks até a animação terminar) ────────────────────────────
if command -v aeternus-splash >/dev/null 2>&1; then
    echo "[xinitrc] splash screen"
    aeternus-splash
fi

# ── Wallpaper ─────────────────────────────────────────────────────────────────
echo "[xinitrc] wallpaper"
if [ -f /usr/local/share/v0rtex/wallpaper.png ]; then
    feh --bg-scale /usr/local/share/v0rtex/wallpaper.png &
elif [ -f ~/.config/i3/wallpaper.png ]; then
    feh --bg-scale ~/.config/i3/wallpaper.png &
else
    xsetroot -solid "#000000" 2>/dev/null || true
fi

# ── Compositor ────────────────────────────────────────────────────────────────
echo "[xinitrc] picom"
if command -v picom >/dev/null 2>&1; then
    if [ -f ~/.config/picom/picom.conf ]; then
        picom --config ~/.config/picom/picom.conf -b \
            2>/dev/null || picom -b 2>/dev/null
    else
        picom -b 2>/dev/null
    fi
fi

# ── Desktop panel (top bar) ───────────────────────────────────────────────────
if command -v aeternus-panel >/dev/null 2>&1; then
    echo "[xinitrc] aeternus-panel"
    aeternus-panel &
fi

# ── Desktop taskbar (bottom bar) ──────────────────────────────────────────────
if command -v aeternus-taskbar >/dev/null 2>&1; then
    echo "[xinitrc] aeternus-taskbar"
    aeternus-taskbar &
fi

# ── Notifications ─────────────────────────────────────────────────────────────
dunst &

# ── Network tray ──────────────────────────────────────────────────────────────
nm-applet &

# ── Window manager ─────────────────────────────────────────────────────────────
echo "[xinitrc] iniciando i3"
exec i3
echo "[xinitrc] AVISO: i3 encerrou — verifique /tmp/v0rtex-session.log"
