#!/usr/bin/env bash
# V0rtexOS — Variáveis globais de ambiente

# ── Diretórios de ferramentas ──────────────────
export VORTEX_HOME="/opt/vortex"
export TOOLS="$VORTEX_HOME"
export EXPLOITS="/opt/exploits"
export CVE_DIR="/opt/cve"
export WORDLISTS="/opt/wordlists"
export SCRIPTS="/opt/scripts"
export VORTEX_OUTPUT="/tmp/vortex-scans"

# ── Path estendido ─────────────────────────────
export PATH="$PATH:/usr/local/bin:/opt/vortex/bin:$HOME/.local/bin:$HOME/go/bin"

# ── Python pip usuário ─────────────────────────
export PYTHONUSERBASE="$HOME/.local"
export PIP_REQUIRE_VIRTUALENV=false

# ── Go ─────────────────────────────────────────
export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"

# ── Privacidade ────────────────────────────────
export DO_NOT_TRACK=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export NEXT_TELEMETRY_DISABLED=1
export HOMEBREW_NO_ANALYTICS=1

# ── Tor / Proxychains ──────────────────────────
export TORSOCKS_CONF="/etc/tor/torsocks.conf"
export HTTP_PROXY="socks5://127.0.0.1:9050"
export HTTPS_PROXY="socks5://127.0.0.1:9050"

# ── GTK / UI Theme ────────────────────────────
export GTK_THEME="Adwaita:dark"
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export QT_STYLE_OVERRIDE="Adwaita-dark"
export QT_QPA_PLATFORMTHEME="gtk3"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# ── Font rendering ────────────────────────────
export FREETYPE_PROPERTIES="truetype:interpreter-version=40"

# ── Cores ANSI para scripts ────────────────────
export C_RED='\033[1;31m'
export C_GRAY='\033[1;37m'
export C_WHITE='\033[0;37m'
export C_RESET='\033[0m'

# ── Proteger ptrace por padrão ─────────────────
[[ -f /proc/sys/kernel/yama/ptrace_scope ]] && \
    echo 1 > /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || true
