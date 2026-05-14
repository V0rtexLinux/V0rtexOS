#!/bin/sh
# V0rtexOS — xinitrc
# Boot sequence: splash → panel → i3wm

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=i3

# Cursor
xsetroot -cursor_name left_ptr

# ── Splash screen (blocks until animation finishes) ──────────────────────────
if command -v aeternus-splash >/dev/null 2>&1; then
    aeternus-splash
fi

# ── Wallpaper ─────────────────────────────────────────────────────────────────
if [ -f /usr/local/share/v0rtex/wallpaper.png ]; then
    feh --bg-scale /usr/local/share/v0rtex/wallpaper.png &
elif [ -f ~/.config/i3/wallpaper.png ]; then
    feh --bg-scale ~/.config/i3/wallpaper.png &
else
    xsetroot -solid "#000000"
fi

# ── Compositor ────────────────────────────────────────────────────────────────
picom --config ~/.config/picom/picom.conf -b &

# ── Desktop panel (top bar) ───────────────────────────────────────────────────
if command -v aeternus-panel >/dev/null 2>&1; then
    aeternus-panel &
fi

# ── Desktop taskbar (bottom bar) ──────────────────────────────────────────────
if command -v aeternus-taskbar >/dev/null 2>&1; then
    aeternus-taskbar &
fi

# ── Notifications ─────────────────────────────────────────────────────────────
dunst &

# ── Network tray ──────────────────────────────────────────────────────────────
nm-applet &

# ── Window manager ────────────────────────────────────────────────────────────
exec i3
