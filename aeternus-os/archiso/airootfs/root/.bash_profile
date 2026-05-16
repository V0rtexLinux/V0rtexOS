#!/bin/bash
# V0rtexOS — bash login profile
# Se zsh está disponível, troca para ele imediatamente.
# Isso garante que X sobe mesmo se o shell no /etc/passwd ainda é bash.

if [[ -x /usr/bin/zsh ]]; then
    exec /usr/bin/zsh -l
fi

# Fallback se zsh não estiver disponível: sobe X direto do bash
if [[ -z "${DISPLAY}${WAYLAND_DISPLAY}" ]] && [[ "$(tty)" == /dev/tty1 ]]; then
    export XAUTHORITY="${HOME}/.Xauthority"
    touch "$XAUTHORITY"
    chmod 600 "$XAUTHORITY"

    export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    echo "[v0rtex] Iniciando Xorg (bash fallback)..."
    export XAUTHORITY="${HOME}/.Xauthority"
    touch "$XAUTHORITY"
    startx /root/.xinitrc -- :0 vt1 -keeptty \
        -logfile /tmp/xorg.log -logverbose 3
fi
