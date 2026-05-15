#!/bin/sh
# V0rtexOS — xinitrc
# Boot sequence: detecção de ambiente → splash → compositor adaptativo → i3wm

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=i3

# Log file para diagnóstico
XLOG=/tmp/v0rtex-session.log
exec > "$XLOG" 2>&1

echo "[xinitrc] $(date) — iniciando sessão X"

# ── Carregar detecção de ambiente ─────────────────────────────────────────────
# /run/v0rtex/env é gerado pelo serviço vortex-detect-env (systemd, antes do X)
VORTEX_HW_PROFILE="reduced"
VORTEX_IS_VM=1
VORTEX_VM_VENDOR="desconhecido"
VORTEX_PICOM_BACKEND="xrender"

if [ -f /run/v0rtex/env ]; then
    # shellcheck disable=SC1091
    . /run/v0rtex/env
    echo "[xinitrc] Ambiente carregado: IS_VM=$VORTEX_IS_VM VENDOR='$VORTEX_VM_VENDOR' PROFILE=$VORTEX_HW_PROFILE"
else
    # Fallback: tentar detectar agora mesmo
    echo "[xinitrc] /run/v0rtex/env não encontrado — rodando detecção inline"
    if command -v vortex-detect-env >/dev/null 2>&1; then
        vortex-detect-env 2>/dev/null || true
        [ -f /run/v0rtex/env ] && . /run/v0rtex/env
    fi
fi

# Cursor
xsetroot -cursor_name left_ptr 2>/dev/null || true

# ── Splash screen ─────────────────────────────────────────────────────────────
# Perfil "minimal" (VectrasVM/Android): splash mais leve — sem animações pesadas
if command -v aeternus-splash >/dev/null 2>&1; then
    echo "[xinitrc] iniciando splash screen (perfil: $VORTEX_HW_PROFILE)"
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

# ── Compositor adaptativo ─────────────────────────────────────────────────────
# full    → picom GLX com blur e efeitos completos (hardware real)
# reduced → picom xrender com sombras (VMs padrão: QEMU, VMware, VirtualBox)
# minimal → sem compositor (VectrasVM/Android — desempenho crítico)
echo "[xinitrc] compositor: perfil=$VORTEX_HW_PROFILE backend=$VORTEX_PICOM_BACKEND"

if [ "$VORTEX_HW_PROFILE" = "minimal" ]; then
    echo "[xinitrc] perfil minimal — compositor desativado (VectrasVM/Android)"
elif command -v picom >/dev/null 2>&1; then
    # Preferir o picom.conf gerado em tempo de boot (adaptado ao perfil)
    if [ -s /run/v0rtex/picom.conf ]; then
        picom --config /run/v0rtex/picom.conf -b 2>>/tmp/v0rtex-picom.log &
        echo "[xinitrc] picom iniciado com config de runtime (/run/v0rtex/picom.conf)"
    elif [ -f ~/.config/picom/picom.conf ]; then
        picom --config ~/.config/picom/picom.conf -b 2>>/tmp/v0rtex-picom.log &
        echo "[xinitrc] picom iniciado com config estática (~/.config/picom/picom.conf)"
    else
        picom -b 2>>/tmp/v0rtex-picom.log &
        echo "[xinitrc] picom iniciado sem config"
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

# ── Notificação de ambiente ao usuário ───────────────────────────────────────
# Após 3s, exibe uma notificação com o ambiente detectado (se dunst estiver ativo)
if [ "$VORTEX_IS_VM" = "1" ]; then
    ENV_MSG="VM detectada: $VORTEX_VM_VENDOR | Perfil: $VORTEX_HW_PROFILE"
else
    ENV_MSG="Hardware real detectado | Perfil: $VORTEX_HW_PROFILE (efeitos completos)"
fi
(sleep 4 && command -v notify-send >/dev/null 2>&1 && \
    notify-send -t 4000 -i dialog-information "V0rtex — Ambiente" "$ENV_MSG") &

# ── Notifications ─────────────────────────────────────────────────────────────
dunst & 2>/dev/null || true

# ── Network tray ──────────────────────────────────────────────────────────────
nm-applet & 2>/dev/null || true

# ── Window manager ────────────────────────────────────────────────────────────
echo "[xinitrc] iniciando i3 (IS_VM=$VORTEX_IS_VM PROFILE=$VORTEX_HW_PROFILE)"
exec i3 2>>/tmp/v0rtex-i3.log
echo "[xinitrc] i3 encerrado com código $?"
