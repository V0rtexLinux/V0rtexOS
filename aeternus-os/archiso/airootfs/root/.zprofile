# V0rtexOS — zsh login profile (sourced antes do .zshrc para login shells)
# Auto-start Xorg quando logado no tty1

if [[ -z "${DISPLAY}${WAYLAND_DISPLAY}" ]] && [[ "$(tty)" == /dev/tty1 ]]; then
    /usr/local/bin/v0rtex-startx
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        echo ""
        echo "[v0rtex] ERRO: Xorg encerrou (código $EXIT_CODE)"
        echo "[v0rtex] Diagnóstico:"
        echo "  cat /tmp/xorg.log"
        echo "  cat /tmp/v0rtex-session.log"
        echo "  cat /tmp/v0rtex-i3.log"
    fi
fi
