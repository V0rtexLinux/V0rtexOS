#!/usr/bin/env bash
# AETERNUS OS — Linux Privilege Escalation Toolkit
# Executa automaticamente os principais vetores de privesc
# Uso: sudo privesc-linux.sh [--auto]

RED='\033[1;31m' GRN='\033[1;32m' YEL='\033[1;33m' CYN='\033[1;36m' RST='\033[0m' BOLD='\033[1m'
ok()   { echo -e "${GRN}[+]${RST} $*"; }
warn() { echo -e "${YEL}[!]${RST} $*"; }
info() { echo -e "${CYN}[*]${RST} $*"; }
vuln() { echo -e "\n${RED}${BOLD}[VULN]${RST}${RED} $*${RST}"; }
hdr()  { echo -e "\n${CYN}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"; }

OS=$(uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
HOSTNAME=$(hostname)
USER=$(id -un)
GROUPS=$(id -Gn)

echo -e "\n${CYN}╔══════════════════════════════════════════════════╗"
echo    "║  AETERNUS — Linux PrivEsc Checker              ║"
echo -e "╚══════════════════════════════════════════════════╝${RST}"
echo -e "  Host   : $HOSTNAME | $OS | $KERNEL | $ARCH"
echo -e "  User   : $USER | $GROUPS"
echo

# ── 1. Informações do sistema ─────────────────────
hdr "SISTEMA"
info "OS Release:" && cat /etc/os-release 2>/dev/null | head -5 || true
info "Processos root:" && ps aux | grep -E "^root" | head -10 || true

# ── 2. SUDO sem senha ─────────────────────────────
hdr "SUDO"
sudo -l 2>/dev/null | grep -iE "NOPASSWD|ALL" && vuln "SUDO sem senha detectado!" || info "Sem SUDO NOPASSWD"

# ── 3. SUID/SGID bits ─────────────────────────────
hdr "SUID/SGID BINARIES"
info "Buscando binários SUID..."
SUID=$(find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | sort)
echo "$SUID"
KNOWN_GTFO=(nmap vim nano find bash sh python python3 perl ruby lua awk gawk man less more zip tar curl wget git env tclsh expect node php ruby lua)
for bin in $SUID; do
    for gtfo in "${KNOWN_GTFO[@]}"; do
        [[ "$bin" == *"/$gtfo" ]] && vuln "GTFOBins SUID: $bin → https://gtfobins.github.io/gtfobins/$gtfo/#suid"
    done
done

# ── 4. Capabilities ───────────────────────────────
hdr "CAPABILITIES"
getcap -r / 2>/dev/null | tee /tmp/caps.txt
grep -E "cap_setuid|cap_net_raw|cap_sys_admin|cap_dac_read_search" /tmp/caps.txt && \
    vuln "Capabilities perigosas encontradas!"

# ── 5. Cron jobs ──────────────────────────────────
hdr "CRON JOBS"
cat /etc/crontab 2>/dev/null && ls /etc/cron* 2>/dev/null
crontab -l 2>/dev/null
for user in $(cut -d: -f1 /etc/passwd); do
    crontab -u "$user" -l 2>/dev/null && info "Cron de $user acima"
done

# ── 6. Permissões de arquivos sensíveis ───────────
hdr "ARQUIVOS SENSÍVEIS"
for f in /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config; do
    if [[ -w "$f" ]]; then
        vuln "Arquivo writable pelo usuário atual: $f"
    elif [[ -r "$f" ]] && [[ "$f" == "/etc/shadow" ]]; then
        vuln "/etc/shadow legível! Extraindo hashes..."
        cat /etc/shadow
    fi
done

# ── 7. Variáveis PATH e scripts writable ──────────
hdr "PATH HIJACKING"
info "PATH atual: $PATH"
for p in $(echo "$PATH" | tr ':' '\n'); do
    [[ -w "$p" ]] && vuln "Diretório writable no PATH: $p"
done

# ── 8. Serviços rodando como root ─────────────────
hdr "SERVIÇOS ROOT"
ps aux 2>/dev/null | awk '$1=="root" && $11!~/^\[/ {print $1,$11}' | sort -u | head -20

# ── 9. Arquivos writable em locais críticos ────────
hdr "ARQUIVOS WRITABLE CRÍTICOS"
find /etc /usr/local/bin /usr/bin /bin /sbin -writable -type f 2>/dev/null | head -20 | \
    while read -r f; do vuln "Writable: $f"; done

# ── 10. NFS misconfiguration ──────────────────────
hdr "NFS"
cat /etc/exports 2>/dev/null | grep -v "^#" | grep "no_root_squash" && \
    vuln "NFS com no_root_squash!" || info "NFS: OK"

# ── 11. Docker/LXC escape ─────────────────────────
hdr "CONTAINERS"
[[ -f /.dockerenv ]] && vuln "Dentro de container Docker! Verifique deepce."
id | grep -q docker && vuln "Usuário no grupo docker → sudo equivalente!"
id | grep -q lxd   && vuln "Usuário no grupo lxd → escalada possível!"

# ── 12. Kernel exploits ───────────────────────────
hdr "KERNEL EXPLOITS"
info "Kernel: $KERNEL"
info "Executando Linux Exploit Suggester..."
perl /usr/local/bin/les2.pl 2>/dev/null | grep -E "CVE|exploit|vulnerable" | head -20 || \
    info "LES2 não encontrado — instale com install-tools.sh"

# ── 13. Senhas em arquivos ────────────────────────
hdr "SENHAS EM ARQUIVOS"
info "Buscando strings de senha em arquivos de config..."
grep -rI --include="*.conf" --include="*.cfg" --include="*.ini" --include="*.env" \
    -E "(password|passwd|pwd|secret|token|api_key)\s*[=:]" \
    /home /var /etc /opt 2>/dev/null | grep -v Binary | head -30 | \
    while read -r line; do warn "$line"; done

# ── 14. Histórico de comandos ─────────────────────
hdr "HISTÓRICO DE COMANDOS"
cat ~/.bash_history ~/.zsh_history ~/.history 2>/dev/null | \
    grep -iE "(password|passwd|ssh|scp|mysql|psql|curl.*-u|wget.*--user)" | head -20

# ── 15. Resumo ────────────────────────────────────
echo
echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYN}  PRIVESC CHECK CONCLUÍDO${RST}"
echo -e "${CYN}  Para análise completa: linpeas | les2 | pspy64${RST}"
echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
