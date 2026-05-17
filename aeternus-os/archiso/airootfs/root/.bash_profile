#!/bin/bash
# V0rtexOS — bash login profile
# Se zsh está disponível, troca para ele imediatamente.
# Isso garante que X sobe mesmo se o shell no /etc/passwd ainda é bash.

if [[ -x /usr/bin/zsh ]]; then
    exec /usr/bin/zsh -l
fi

# Fallback se zsh não estiver disponível: sobe X direto do bash
if [[ -z "${DISPLAY}${WAYLAND_DISPLAY}" ]] && [[ "$(tty)" == /dev/tty1 ]]; then
    echo "[v0rtex] Iniciando Xorg (bash fallback)..."
    /usr/local/bin/v0rtex-startx
fi
