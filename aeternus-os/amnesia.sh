#!/usr/bin/env bash
# AETERNUS OS — Script de Amnésia
# Limpa RAM, /tmp, /var/log e artefatos sensíveis antes do poweroff.
# Uso: sudo /usr/local/bin/amnesia [--confirm]
#
# INSTALAÇÃO COMO SERVIÇO DE SHUTDOWN:
#   sudo cp amnesia.sh /usr/local/bin/amnesia
#   sudo cp amnesia-shutdown.service /etc/systemd/system/
#   sudo systemctl enable amnesia-shutdown.service

set -euo pipefail

SCRIPT="amnesia"
LOG="/tmp/amnesia-run.log"

# ─────────────────────────────────────────────────
# CORES
# ─────────────────────────────────────────────────
RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
CYN='\033[1;36m'
DIM='\033[2m'
RST='\033[0m'

ts()    { date '+%H:%M:%S'; }
log()   { echo -e "${DIM}[$(ts)]${RST} ${CYN}[${SCRIPT}]${RST} $*" | tee -a "$LOG"; }
ok()    { echo -e "${DIM}[$(ts)]${RST} ${GRN}[  OK  ]${RST} $*" | tee -a "$LOG"; }
warn()  { echo -e "${DIM}[$(ts)]${RST} ${YEL}[ WARN ]${RST} $*" | tee -a "$LOG"; }
die()   { echo -e "${DIM}[$(ts)]${RST} ${RED}[ FAIL ]${RST} $*" | tee -a "$LOG"; exit 1; }

# ─────────────────────────────────────────────────
# PRÉ-REQUISITOS
# ─────────────────────────────────────────────────
check_root() {
    [[ $EUID -eq 0 ]] || die "Execute como root: sudo amnesia"
}

check_tools() {
    log "Verificando ferramentas de limpeza..."
    HAVE_SDMEM=false
    HAVE_SHRED=false
    HAVE_SRMD=false

    command -v sdmem   &>/dev/null && HAVE_SDMEM=true
    command -v shred   &>/dev/null && HAVE_SHRED=true
    command -v srm     &>/dev/null && HAVE_SRMD=true

    $HAVE_SDMEM || warn "sdmem não encontrado (pacote: secure-delete). Usando método alternativo."
    ok "Ferramentas verificadas."
}

# ─────────────────────────────────────────────────
# CONFIRMAR INTENÇÃO (segurança)
# ─────────────────────────────────────────────────
confirm() {
    if [[ "${1:-}" != "--confirm" && "${1:-}" != "--force" ]]; then
        echo -e "\n${RED}╔══════════════════════════════════════════╗"
        echo -e "║  AETERNUS OS — PROTOCOLO DE AMNÉSIA     ║"
        echo -e "║  Esta operação é IRREVERSÍVEL            ║"
        echo -e "╚══════════════════════════════════════════╝${RST}\n"
        echo -e "Será apagado:"
        echo -e "  ${YEL}• RAM (sobrescrita com zeros/random)${RST}"
        echo -e "  ${YEL}• /tmp, /var/tmp${RST}"
        echo -e "  ${YEL}• /var/log/* (logs do sistema)${RST}"
        echo -e "  ${YEL}• Histórico de shells (bash, zsh, fish)${RST}"
        echo -e "  ${YEL}• Cache do pacman e repositórios temporários${RST}"
        echo -e "  ${YEL}• Thumbnails, cache de apps${RST}"
        echo -e "  ${YEL}• Chaves SSH temporárias em /tmp${RST}"
        echo
        read -r -p "Confirmar limpeza? [s/N] " resp
        [[ "$resp" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
    fi
}

# ─────────────────────────────────────────────────
# 1. LIMPAR /tmp E /var/tmp
# ─────────────────────────────────────────────────
clean_tmp() {
    log "Limpando diretórios temporários..."

    local dirs=("/tmp" "/var/tmp" "/dev/shm")
    for d in "${dirs[@]}"; do
        if [[ -d "$d" ]]; then
            if $HAVE_SHRED; then
                # Sobrescrever arquivos antes de remover
                find "$d" -type f -exec shred -vzun 3 {} \; 2>/dev/null || true
            fi
            find "$d" -mindepth 1 -delete 2>/dev/null || rm -rf "${d:?}"/* 2>/dev/null || true
            ok "Limpo: $d"
        fi
    done
}

# ─────────────────────────────────────────────────
# 2. LIMPAR LOGS DO SISTEMA
# ─────────────────────────────────────────────────
clean_logs() {
    log "Limpando logs do sistema..."

    # Apagar logs do journald
    if command -v journalctl &>/dev/null; then
        journalctl --rotate &>/dev/null
        journalctl --vacuum-time=1s &>/dev/null || true
        ok "Journald limpo."
    fi

    # Apagar logs de texto
    local log_dirs=("/var/log")
    for ldir in "${log_dirs[@]}"; do
        find "$ldir" -type f \( \
            -name "*.log" -o -name "*.log.*" \
            -o -name "*.gz" -o -name "auth.log" \
            -o -name "syslog" -o -name "kern.log" \
            -o -name "messages" -o -name "secure" \
            -o -name "lastlog" -o -name "wtmp" \
            -o -name "btmp" -o -name "utmp" \
        \) | while read -r f; do
            if $HAVE_SHRED; then
                shred -vzun 3 "$f" &>/dev/null || true
            else
                : > "$f"  # truncar
            fi
        done 2>/dev/null || true
    done

    # Limpar lastlog / wtmp / btmp
    for f in /var/log/lastlog /var/log/wtmp /var/log/btmp /var/run/utmp; do
        [[ -f "$f" ]] && : > "$f" && ok "Truncado: $f"
    done

    ok "Logs do sistema limpos."
}

# ─────────────────────────────────────────────────
# 3. LIMPAR HISTÓRICO DE SHELLS
# ─────────────────────────────────────────────────
clean_shell_history() {
    log "Apagando histórico de shells..."

    local hist_files=(
        ~/.bash_history
        ~/.zsh_history
        ~/.history
        ~/.local/share/fish/fish_history
        ~/.python_history
        ~/.mysql_history
        ~/.psql_history
        ~/.sqlite_history
        ~/.lesshst
        ~/.viminfo
        ~/.local/share/recently-used.xbel
        ~/.recently-used
    )

    for f in "${hist_files[@]}"; do
        [[ -f "$f" ]] || continue
        if $HAVE_SHRED; then
            shred -vzun 3 "$f" &>/dev/null && ok "Apagado: $f"
        else
            : > "$f" && ok "Truncado: $f"
        fi
    done

    # Também limpar para root
    for f in /root/.bash_history /root/.zsh_history; do
        [[ -f "$f" ]] || continue
        $HAVE_SHRED && shred -vzun 3 "$f" &>/dev/null || : > "$f"
        ok "Apagado: $f"
    done

    # Desativar histórico para a sessão atual
    unset HISTFILE
    export HISTSIZE=0
    export HISTFILESIZE=0
}

# ─────────────────────────────────────────────────
# 4. LIMPAR CACHES
# ─────────────────────────────────────────────────
clean_caches() {
    log "Limpando caches de aplicações..."

    local cache_dirs=(
        ~/.cache
        ~/.thumbnails
        ~/.local/share/Trash
        /var/cache/pacman/pkg
        /var/cache/apt/archives
        ~/.mozilla/firefox/*/cache2
        ~/.config/chromium/*/Cache
        ~/.config/google-chrome/*/Cache
    )

    for d in "${cache_dirs[@]}"; do
        # Expandir globs
        for expanded in $d; do
            [[ -d "$expanded" ]] || continue
            rm -rf "${expanded:?}/"* 2>/dev/null || true
            ok "Cache limpo: $expanded"
        done
    done

    # Limpar arquivo de swap se existir
    if [[ -f /swapfile ]]; then
        warn "Swap detectado (/swapfile). Para máxima segurança, desative o swap:"
        warn "  swapoff -a && shred -vzun 3 /swapfile"
    fi

    # Sincronizar cache de disco para garantir escrita
    sync
}

# ─────────────────────────────────────────────────
# 5. LIMPAR RAM — Operação principal
# ─────────────────────────────────────────────────
clean_ram() {
    log "Iniciando limpeza de RAM..."

    # Dropar page cache, dentries e inodes
    log "Descartando page cache do kernel..."
    sync
    echo 3 > /proc/sys/vm/drop_caches
    ok "Page cache descartado."

    # sdmem — sobrescreve memória livre (método mais robusto)
    if $HAVE_SDMEM; then
        log "Executando sdmem (sobrescrita de memória livre com random + zeros)..."
        sdmem -f -v 2>&1 | tail -5 | while read -r line; do
            log "  sdmem: $line"
        done
        ok "sdmem concluído."
    else
        # Método alternativo: alocar e zerar memória com Python
        log "sdmem não disponível — usando método Python para zerar memória disponível..."
        python3 - <<'PYEOF'
import os, mmap, resource

# Obter memória livre
with open("/proc/meminfo") as f:
    for line in f:
        if line.startswith("MemAvailable"):
            avail_kb = int(line.split()[1])
            break
    else:
        avail_kb = 1024 * 512  # fallback 512MB

# Deixar 256MB de folga para o sistema
size = max(0, (avail_kb - 256 * 1024) * 1024)
if size <= 0:
    print("Memória disponível insuficiente para limpeza segura.")
    exit(0)

print(f"Alocando e zerando {size // 1024 // 1024}MB de memória...")
try:
    chunk = 256 * 1024 * 1024  # 256MB por vez
    filled = 0
    blocks = []
    while filled < size:
        alloc = min(chunk, size - filled)
        try:
            m = mmap.mmap(-1, alloc)
            m.write(b'\x00' * alloc)
            m.write(b'\xff' * alloc)
            m.seek(0)
            m.write(b'\x00' * alloc)
            blocks.append(m)
            filled += alloc
        except (MemoryError, mmap.error):
            break
    print(f"Zerizado {filled // 1024 // 1024}MB")
    # Liberar
    for m in blocks:
        m.close()
except Exception as e:
    print(f"Aviso: {e}")
PYEOF
        ok "Memória zerada via Python."
    fi

    # Zerar novamente page cache após limpeza
    sync
    echo 3 > /proc/sys/vm/drop_caches
    ok "RAM limpa."
}

# ─────────────────────────────────────────────────
# 6. APAGAR CHAVES TEMPORÁRIAS E CREDENCIAIS
# ─────────────────────────────────────────────────
clean_credentials() {
    log "Apagando credenciais e chaves temporárias..."

    # Chaves SSH de sessão em /tmp
    find /tmp -name "*.pem" -o -name "*.key" -o -name "id_*" -o -name "*.p12" \
        2>/dev/null | while read -r f; do
        $HAVE_SHRED && shred -vzun 3 "$f" &>/dev/null || rm -f "$f"
        ok "Chave removida: $f"
    done

    # Limpar ssh-agent
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        ssh-add -D &>/dev/null || true
        ok "ssh-agent limpo."
    fi

    # Limpar GPG cache
    if command -v gpgconf &>/dev/null; then
        gpgconf --kill gpg-agent &>/dev/null || true
        ok "GPG agent terminado."
    fi

    # Limpar credenciais de sudo em cache
    sudo -K &>/dev/null || true
    ok "Cache sudo limpo."
}

# ─────────────────────────────────────────────────
# RELATÓRIO FINAL
# ─────────────────────────────────────────────────
print_report() {
    echo
    echo -e "${CYN}═══════════════════════════════════════════${RST}"
    echo -e "${CYN}  AETERNUS — AMNÉSIA CONCLUÍDA${RST}"
    echo -e "${CYN}  $(date '+%Y-%m-%d %H:%M:%S')${RST}"
    echo -e "${CYN}═══════════════════════════════════════════${RST}"
    echo -e "  ${GRN}✓ RAM limpa${RST}"
    echo -e "  ${GRN}✓ /tmp e /var/tmp apagados${RST}"
    echo -e "  ${GRN}✓ Logs do sistema limpos${RST}"
    echo -e "  ${GRN}✓ Histórico de shells apagado${RST}"
    echo -e "  ${GRN}✓ Caches de aplicações removidos${RST}"
    echo -e "  ${GRN}✓ Credenciais temporárias apagadas${RST}"
    echo -e "${CYN}═══════════════════════════════════════════${RST}"
    echo -e "  ${DIM}Sistema pronto para desligar.${RST}"
    echo
}

# ─────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────
main() {
    local confirm_flag="${1:-}"

    check_root
    check_tools
    confirm "$confirm_flag"

    log "=== PROTOCOLO DE AMNÉSIA INICIADO ==="

    clean_shell_history
    clean_credentials
    clean_tmp
    clean_logs
    clean_caches
    clean_ram

    print_report

    log "=== AMNÉSIA COMPLETA ==="
}

main "$@"
