#!/usr/bin/env bash
# AETERNUS OS — Master Build Script
# Gera a ISO completa baseada em Arch Linux com linux-hardened + BlackArch
# Uso: sudo bash build.sh [--fast|--full]
#
# Requer: archiso mkarchiso pacman git curl (em host Arch Linux)

set -euo pipefail

AETERNUS_VERSION="2.0.$(date +%Y%m%d)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/aeternus-profile"
WORK_DIR="/tmp/aeternus-build-work"
OUT_DIR="$SCRIPT_DIR/release"
LOG_FILE="/tmp/aeternus-build.log"
FAST_MODE="${1:-}"

# Detectar CI (GitHub Actions, GitLab CI, etc.)
CI="${CI:-false}"
[[ -n "${GITHUB_ACTIONS:-}" ]] && CI="true"
[[ -n "${GITLAB_CI:-}"      ]] && CI="true"

RED='\033[1;31m' GRN='\033[1;32m' YEL='\033[1;33m' CYN='\033[1;36m'
BOLD='\033[1m' DIM='\033[2m' RST='\033[0m'

ts()   { date '+%H:%M:%S'; }
log()  { echo -e "${DIM}[$(ts)]${RST} ${CYN}[BUILD]${RST} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${DIM}[$(ts)]${RST} ${GRN}[ OK  ]${RST} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${DIM}[$(ts)]${RST} ${YEL}[WARN ]${RST} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${DIM}[$(ts)]${RST} ${RED}[FAIL ]${RST} $*" | tee -a "$LOG_FILE"; exit 1; }
sec()  {
    echo | tee -a "$LOG_FILE"
    echo -e "${CYN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}" | tee -a "$LOG_FILE"
    echo -e "${CYN}${BOLD}  $*${RST}" | tee -a "$LOG_FILE"
    echo -e "${CYN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}" | tee -a "$LOG_FILE"
}

# ════════════════════════════════════════════════
# 0. VALIDAÇÕES INICIAIS
# ════════════════════════════════════════════════
preflight() {
    [[ $EUID -ne 0 ]] && err "Execute como root: sudo bash build.sh"
    [[ "$(uname -s)" != "Linux" ]] && err "Requer Linux (Arch Linux preferido)"

    sec "PRE-FLIGHT CHECKS"
    local deps=(archiso mkarchiso pacman git curl unzip python3 openssl)
    local missing=()
    for d in "${deps[@]}"; do
        command -v "$d" &>/dev/null && ok "$d ✓" || missing+=("$d")
    done
    [[ ${#missing[@]} -gt 0 ]] && {
        warn "Instalando dependências: ${missing[*]}"
        pacman -Sy --noconfirm --needed "${missing[@]}" || \
            err "Falha ao instalar: ${missing[*]}"
    }

    # Verificar espaço em disco
    # Em CI o /tmp pode ter menos que 20GB — apenas avisa, não bloqueia
    local free_gb
    free_gb=$(df /tmp --output=avail -BG 2>/dev/null | tail -1 | tr -d 'G ' || echo "0")
    local threshold=20
    [[ "$CI" == "true" ]] && threshold=8
    if [[ "$free_gb" -lt "$threshold" ]]; then
        warn "Espaço livre em /tmp: ${free_gb}GB (recomendado ${threshold}GB+)"
        [[ "$CI" != "true" ]] && err "Espaço insuficiente. Libere espaço em /tmp e tente novamente."
    fi
    ok "Espaço disponível: ${free_gb}GB"
    ok "Pre-flight OK"
}

# ════════════════════════════════════════════════
# 1. CHAVES GPG (BlackArch + Arch)
# ════════════════════════════════════════════════
setup_keys() {
    sec "CONFIGURANDO CHAVES GPG"

    # Em CI o workflow já inicializou o keyring com haveged.
    # Fora do CI, inicializa aqui mesmo.
    if [[ "$CI" != "true" ]]; then
        log "Inicializando pacman-key..."
        pacman-key --init
        pacman-key --populate archlinux
    else
        log "CI detectado — keyring já inicializado pelo workflow. Pulando init."
    fi

    # Verificar se BlackArch já está configurado no pacman.conf do host
    if grep -q "\[blackarch\]" /etc/pacman.conf 2>/dev/null; then
        ok "Repositório BlackArch já presente no host"
    else
        log "Adicionando repositório BlackArch ao host..."
        curl -fsSL https://blackarch.org/strap.sh -o /tmp/blackarch-strap.sh
        chmod +x /tmp/blackarch-strap.sh
        bash /tmp/blackarch-strap.sh
        rm -f /tmp/blackarch-strap.sh
        pacman -Sy --noconfirm
        ok "BlackArch adicionado"
    fi

    ok "Chaves GPG configuradas"
}

# ════════════════════════════════════════════════
# 2. INICIALIZAR PERFIL ARCHISO
# ════════════════════════════════════════════════
init_profile() {
    sec "INICIALIZANDO PERFIL ARCHISO"

    [[ -d "$PROFILE_DIR" ]] && {
        log "Removendo perfil anterior..."
        rm -rf "$PROFILE_DIR"
    }

    log "Copiando perfil releng como base..."
    cp -r /usr/share/archiso/configs/releng "$PROFILE_DIR"
    ok "Perfil base copiado"

    # Substituir pacman.conf
    cp "$SCRIPT_DIR/archiso/pacman.conf" "$PROFILE_DIR/pacman.conf"
    ok "pacman.conf configurado (Arch + BlackArch)"

    # Substituir profiledef.sh
    cp "$SCRIPT_DIR/archiso/profiledef.sh" "$PROFILE_DIR/profiledef.sh"
    chmod +x "$PROFILE_DIR/profiledef.sh"
    ok "profiledef.sh configurado"

    # Lista de pacotes
    cp "$SCRIPT_DIR/archiso/packages.x86_64" "$PROFILE_DIR/packages.x86_64"
    local pkg_count
    pkg_count=$(grep -cE "^[^#[:space:]]" "$PROFILE_DIR/packages.x86_64")
    ok "Lista de pacotes: $pkg_count pacotes"
}

# ════════════════════════════════════════════════
# 3. POPULAR AIROOTFS
# ════════════════════════════════════════════════
populate_airootfs() {
    sec "POPULANDO AIROOTFS"
    local air="$PROFILE_DIR/airootfs"

    # Estrutura de diretórios
    log "Criando estrutura de diretórios..."
    mkdir -p \
        "$air/usr/local/bin" \
        "$air/opt/aeternus" \
        "$air/opt/wordlists" \
        "$air/opt/cve" \
        "$air/opt/exploits" \
        "$air/opt/scripts" \
        "$air/etc/systemd/system/multi-user.target.wants" \
        "$air/etc/systemd/system/halt.target.wants" \
        "$air/etc/tor" \
        "$air/etc/dnscrypt-proxy" \
        "$air/etc/apparmor.d" \
        "$air/etc/profile.d" \
        "$air/root/.config/i3" \
        "$air/root/.config/alacritty" \
        "$air/root/.config/picom" \
        "$air/root/.config/nvim" \
        "$air/root/.config/starship" \
        "$air/var/lib/aeternus" \
        "$air/var/log/aeternus"

    # ── Binários principais ───────────────────────
    log "Instalando binários principais..."
    install -Dm755 "$SCRIPT_DIR/ghost-protocol/ghost-protocol.sh" \
        "$air/usr/local/bin/ghost-protocol.sh"
    install -Dm755 "$SCRIPT_DIR/justice/aet-scan.py"  "$air/usr/local/bin/aet-scan"
    install -Dm755 "$SCRIPT_DIR/justice/aet-nuke.py"  "$air/usr/local/bin/aet-nuke"
    install -Dm755 "$SCRIPT_DIR/amnesia.sh"            "$air/usr/local/bin/amnesia"
    install -Dm755 "$SCRIPT_DIR/tools/install-tools.sh" "$air/usr/local/bin/install-tools"
    install -Dm755 "$SCRIPT_DIR/tools/payload-gen.sh"   "$air/usr/local/bin/payload-gen"
    install -Dm755 "$SCRIPT_DIR/tools/network-attacks.sh" "$air/usr/local/bin/net-attack"
    install -Dm755 "$SCRIPT_DIR/tools/privesc-linux.sh"  "$air/usr/local/bin/privesc"
    install -Dm755 "$SCRIPT_DIR/tools/web-enum.sh"       "$air/usr/local/bin/web-enum"
    install -Dm755 "$SCRIPT_DIR/tools/ad-attack.sh"        "$air/usr/local/bin/ad-attack"
    install -Dm755 "$SCRIPT_DIR/tools/wireless-attack.sh"  "$air/usr/local/bin/wireless-attack"
    install -Dm755 "$SCRIPT_DIR/tools/post-exploit.sh"     "$air/usr/local/bin/post-exploit"
    install -Dm755 "$SCRIPT_DIR/tools/shell-gen.sh"        "$air/usr/local/bin/shell-gen"
    install -Dm755 "$SCRIPT_DIR/tools/tunnel-setup.sh"     "$air/usr/local/bin/tunnel-setup"
    install -Dm755 "$SCRIPT_DIR/tools/exploit-db-search.py" "$air/usr/local/bin/exploit-search"
    ok "Binários instalados"

    # ── Serviços systemd ──────────────────────────
    log "Instalando serviços systemd..."
    install -Dm644 "$SCRIPT_DIR/ghost-protocol/ghost-protocol.service" \
        "$air/etc/systemd/system/ghost-protocol.service"
    install -Dm644 "$SCRIPT_DIR/ghost-protocol/amnesia-shutdown.service" \
        "$air/etc/systemd/system/amnesia-shutdown.service"
    install -Dm644 "$SCRIPT_DIR/archiso/airootfs/etc/systemd/system/aet-nuke.service" \
        "$air/etc/systemd/system/aet-nuke.service"
    install -Dm644 "$SCRIPT_DIR/archiso/airootfs/etc/systemd/system/dnscrypt-proxy.service" \
        "$air/etc/systemd/system/dnscrypt-proxy.service"

    # Habilitar serviços
    for svc in ghost-protocol aet-nuke NetworkManager tor apparmor; do
        ln -sf "/etc/systemd/system/${svc}.service" \
            "$air/etc/systemd/system/multi-user.target.wants/${svc}.service" 2>/dev/null || true
    done
    for svc in amnesia-shutdown; do
        ln -sf "/etc/systemd/system/${svc}.service" \
            "$air/etc/systemd/system/halt.target.wants/${svc}.service" 2>/dev/null || true
    done
    ok "Serviços configurados"

    # ── Configurações ─────────────────────────────
    log "Copiando configurações..."
    cp "$SCRIPT_DIR/archiso/airootfs/etc/tor/torrc" "$air/etc/tor/torrc"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/dnscrypt-proxy/dnscrypt-proxy.toml" \
        "$air/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/proxychains.conf" "$air/etc/proxychains.conf"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/profile.d/aeternus.sh" \
        "$air/etc/profile.d/aeternus.sh"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/default/grub"  "$air/etc/default/grub"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/hostname"       "$air/etc/hostname"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/locale.gen"     "$air/etc/locale.gen"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/locale.conf"    "$air/etc/locale.conf"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/vconsole.conf"  "$air/etc/vconsole.conf"
    cp "$SCRIPT_DIR/archiso/airootfs/etc/apparmor.d/aet-scan" \
        "$air/etc/apparmor.d/aet-scan" 2>/dev/null || true
    ok "Configurações copiadas"

    # ── Kernel e sysctl ───────────────────────────
    log "Configurando hardening de kernel..."
    install -Dm644 "$SCRIPT_DIR/kernel/hardened.conf" \
        "$air/etc/modprobe.d/aeternus-blacklist.conf"
    install -Dm644 "$SCRIPT_DIR/kernel/hardened-sysctl.conf" \
        "$air/etc/sysctl.d/99-aeternus.conf"
    install -Dm644 "$SCRIPT_DIR/kernel/mkinitcpio-hardened.conf" \
        "$air/etc/mkinitcpio.conf"
    ok "Kernel hardening configurado"

    # ── dotfiles do root ──────────────────────────
    log "Configurando dotfiles..."
    cp "$SCRIPT_DIR/archiso/airootfs/root/.zshrc"              "$air/root/.zshrc"
    cp "$SCRIPT_DIR/archiso/airootfs/root/.tmux.conf"          "$air/root/.tmux.conf"
    cp "$SCRIPT_DIR/archiso/airootfs/root/.config/starship.toml" \
        "$air/root/.config/starship.toml"
    cp "$SCRIPT_DIR/archiso/airootfs/root/.config/nvim/init.lua" \
        "$air/root/.config/nvim/init.lua"
    cp "$SCRIPT_DIR/archiso/airootfs/root/.config/i3/config"   \
        "$air/root/.config/i3/config"
    cp "$SCRIPT_DIR/config/i3/i3status.conf"   "$air/root/.config/i3/i3status.conf"
    cp "$SCRIPT_DIR/config/i3/picom.conf"       "$air/root/.config/picom/picom.conf"
    cp "$SCRIPT_DIR/config/alacritty/alacritty.toml" \
        "$air/root/.config/alacritty/alacritty.toml"

    # Shell padrão para root = zsh
    echo "chsh -s /bin/zsh root" >> "$air/etc/profile.d/aeternus.sh"

    # Banner ASCII
    cat > "$air/etc/aeternus-banner" <<'BANNER'
    ___   _____________________  _   ____  _______
   /   | / ____/_  __/ ____/ \ | | / / / / / ___/
  / /| |/ __/   / / / __/ /  \| |/ / / / /\__ \
 / ___ / /___  / / / /___/ /|  / /_/ / /___/ __/
/_/  |_/_____/ /_/ /_____/_/ |_/\____/\____/____/
                          Grey Hat Linux — Hardened
BANNER

    # MOTD
    cat > "$air/etc/motd" <<'MOTD'
╔══════════════════════════════════════════════════════════╗
║  AETERNUS OS — Grey Hat Security Distribution           ║
║  Kernel: linux-hardened | Tor+VPN Kill Switch           ║
╠══════════════════════════════════════════════════════════╣
║  TOOLS:  aet-scan  aet-nuke  payload-gen  web-enum      ║
║          net-attack  ad-attack  wireless-attack          ║
║          privesc  post-exploit  install-tools            ║
╠══════════════════════════════════════════════════════════╣
║  PRIVACY: Ghost Protocol auto-starts on boot            ║
║  AMNESIA: sudo amnesia --confirm  |  safe-off            ║
╚══════════════════════════════════════════════════════════╝
MOTD

    ok "Dotfiles e configs configurados"
}

# ════════════════════════════════════════════════
# 4. CUSTOMIZAR BOOTLOADER
# ════════════════════════════════════════════════
configure_boot() {
    sec "CONFIGURANDO BOOTLOADER"

    local air="$PROFILE_DIR/airootfs"

    # archiso espera o grub.cfg em $PROFILE_DIR/grub/grub.cfg
    mkdir -p "$PROFILE_DIR/grub"
    mkdir -p "$air/boot/grub"
    cat > "$PROFILE_DIR/grub/grub.cfg" <<'GRUBCFG'
set default=0
set timeout=5
set gfxpayload=keep
insmod all_video
insmod gzio
insmod part_gpt
insmod cryptodisk
insmod luks
insmod gcry_rijndael
insmod gcry_sha256
insmod ext2

menuentry "AETERNUS OS" --class aeternus --class gnu-linux --class gnu --class os {
    set gfxpayload=keep
    linux /arch/boot/x86_64/vmlinuz-linux-hardened \
        archisobasedir=arch \
        archisolabel=AETERNUS_OS \
        quiet loglevel=0 \
        apparmor=1 security=apparmor \
        page_poison=1 slab_nomerge \
        pti=on vsyscall=none \
        spectre_v2=on spec_store_bypass_disable=on \
        l1tf=full,force mds=full,nosmt \
        mitigations=auto,nosmt \
        rd.systemd.show_status=auto
    initrd /arch/boot/x86_64/initramfs-linux-hardened.img
}

menuentry "AETERNUS OS (Debug/Verbose)" --class aeternus {
    linux /arch/boot/x86_64/vmlinuz-linux-hardened \
        archisobasedir=arch archisolabel=AETERNUS_OS \
        apparmor=1 security=apparmor
    initrd /arch/boot/x86_64/initramfs-linux-hardened.img
}

menuentry "Reboot" {
    reboot
}
menuentry "Power Off" {
    halt
}
GRUBCFG
    ok "GRUB configurado"
}

# ════════════════════════════════════════════════
# 5. BUILD DA ISO
# ════════════════════════════════════════════════
build_iso() {
    sec "CONSTRUINDO ISO"

    [[ -d "$WORK_DIR" ]] && {
        log "Limpando work dir anterior..."
        rm -rf "$WORK_DIR"
    }
    mkdir -p "$OUT_DIR"

    log "Iniciando mkarchiso..."
    log "Isso pode levar 15-45 minutos dependendo do hardware e conexão."
    log "Log completo: $LOG_FILE"
    echo

    local START_TIME
    START_TIME=$(date +%s)

    mkarchiso -v \
        -w "$WORK_DIR" \
        -o "$OUT_DIR" \
        "$PROFILE_DIR" 2>&1 | tee -a "$LOG_FILE"

    local END_TIME ELAPSED
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))

    ok "Build concluído em $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"
}

# ════════════════════════════════════════════════
# 6. PÓS-BUILD: VERIFICAÇÃO E CHECKSUM
# ════════════════════════════════════════════════
post_build() {
    sec "PÓS-BUILD"

    local iso
    iso=$(find "$OUT_DIR" -name "aeternus-os-*.iso" | sort | tail -1)
    [[ -z "$iso" ]] && err "ISO não encontrada em $OUT_DIR"

    local size
    size=$(du -sh "$iso" | cut -f1)
    ok "ISO: $iso ($size)"

    log "Gerando checksums..."
    sha256sum "$iso" > "${iso}.sha256"
    md5sum    "$iso" > "${iso}.md5"
    ok "SHA256: $(cat "${iso}.sha256" | awk '{print $1}')"

    echo
    echo -e "${GRN}${BOLD}╔═══════════════════════════════════════════════════════╗${RST}"
    echo -e "${GRN}${BOLD}║  AETERNUS OS BUILD CONCLUÍDO                         ║${RST}"
    echo -e "${GRN}${BOLD}╠═══════════════════════════════════════════════════════╣${RST}"
    printf "${GRN}${BOLD}║  ISO     : %-43s║${RST}\n" "$(basename "$iso")"
    printf "${GRN}${BOLD}║  Tamanho : %-43s║${RST}\n" "$size"
    printf "${GRN}${BOLD}║  Versão  : %-43s║${RST}\n" "$AETERNUS_VERSION"
    echo -e "${GRN}${BOLD}╠═══════════════════════════════════════════════════════╣${RST}"
    echo -e "${GRN}${BOLD}║  Gravar em USB:                                      ║${RST}"
    printf "${GRN}${BOLD}║  sudo dd if=%s of=/dev/sdX bs=4M status=progress ║${RST}\n" "$(basename "$iso")"
    echo -e "${GRN}${BOLD}║  sync                                                ║${RST}"
    echo -e "${GRN}${BOLD}╚═══════════════════════════════════════════════════════╝${RST}"
    echo
    echo -e "${YEL}  Após o boot:${RST}"
    echo -e "  • Ghost Protocol ativa automaticamente (VPN+Tor kill switch)"
    echo -e "  • Instalar tools: sudo install-tools all"
    echo -e "  • Scanner: sudo aet-scan -p vuln <alvo>"
    echo -e "  • Defesa ativa: sudo aet-nuke monitor"
    echo -e "  • Desligar com amnésia: safe-off"
    echo
}

# ════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════
main() {
    # clear só em terminal interativo — não em CI
    [[ "$CI" != "true" ]] && clear
    echo -e "${CYN}${BOLD}"
    cat <<'HEADER'
    ___   _____________________  _   ____  _______
   /   | / ____/_  __/ ____/ \ | | / / / / / ___/
  / /| |/ __/   / / / __/ /  \| |/ / / / /\__ \
 / ___ / /___  / / / /___/ /|  / /_/ / /___/ __/
/_/  |_/_____/ /_/ /_____/_/ |_/\____/\____/____/
HEADER
    echo -e "${RST}${CYN}  Grey Hat Linux — Build System v2.0${RST}"
    echo -e "${DIM}  Log: $LOG_FILE${RST}"
    echo

    preflight
    setup_keys
    init_profile
    populate_airootfs
    configure_boot
    build_iso
    post_build
}

main "$@"
