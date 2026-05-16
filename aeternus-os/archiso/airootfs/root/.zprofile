# V0rtexOS — zsh login profile (sourced antes do .zshrc para login shells)
# Auto-start Xorg quando logado no tty1

if [[ -z "${DISPLAY}${WAYLAND_DISPLAY}" ]] && [[ "$(tty)" == /dev/tty1 ]]; then
    # XAUTHORITY deve ser definido ANTES do startx; sem ele o Xorg recusa conexões
    export XAUTHORITY="${HOME}/.Xauthority"
    touch "$XAUTHORITY"
    chmod 600 "$XAUTHORITY"

    # XDG_RUNTIME_DIR necessário para sockets de sessão
    export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    echo "[v0rtex] Iniciando Xorg... (log: /tmp/xorg.log)"
    export XAUTHORITY="${HOME}/.Xauthority"
    touch "$XAUTHORITY"
    startx "$HOME/.xinitrc" -- :0 vt1 -keeptty \
        -logfile /tmp/xorg.log -logverbose 3
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
