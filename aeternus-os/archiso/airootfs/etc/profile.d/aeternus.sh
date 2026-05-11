#!/usr/bin/env bash
# AETERNUS OS — Variáveis globais de ambiente

# ── Diretórios de ferramentas ──────────────────
export AETERNUS_HOME="/opt/aeternus"
export TOOLS="$AETERNUS_HOME"
export EXPLOITS="/opt/exploits"
export CVE_DIR="/opt/cve"
export WORDLISTS="/opt/wordlists"
export SCRIPTS="/opt/scripts"
export AETERNUS_OUTPUT="/tmp/aeternus-scans"

# ── Path estendido ─────────────────────────────
export PATH="$PATH:/usr/local/bin:/opt/aeternus/bin:$HOME/.local/bin:$HOME/go/bin"

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

# ── Cores ANSI para scripts ────────────────────
export C_RED='\033[1;31m'
export C_GREEN='\033[1;32m'
export C_CYAN='\033[1;36m'
export C_RESET='\033[0m'

# ── Desativar swap em produção (privacidade) ───
# swapoff -a 2>/dev/null &

# ── Proteger ptrace por padrão ─────────────────
[[ -f /proc/sys/kernel/yama/ptrace_scope ]] && \
    echo 1 > /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || true
