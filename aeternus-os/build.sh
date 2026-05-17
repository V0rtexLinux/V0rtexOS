#!/usr/bin/env bash
# V0rtexOS — Master Build Script
# Gera a ISO completa baseada em Arch Linux com linux-hardened + BlackArch
# Uso: sudo bash build.sh [--fast|--full]
#
# Requer: archiso mkarchiso pacman git curl (em host Arch Linux)

set -euo pipefail

VORTEX_VERSION="2.0.$(date +%Y%m%d)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/v0rtex-profile"
LOG_FILE="/tmp/v0rtex-build.log"
FAST_MODE="${1:-}"

# Detectar CI (GitHub Actions, GitLab CI, etc.)
CI="${CI:-false}"
[[ -n "${GITHUB_ACTIONS:-}" ]] && CI="true"
[[ -n "${GITLAB_CI:-}"      ]] && CI="true"

# Em CI usa /mnt (disco de dados ~28 GB no GitHub Actions, vs ~14 GB em /)
# Localmente usa /tmp para builds normais
if [[ "$CI" == "true" ]]; then
    WORK_DIR="/mnt/v0rtex-build-work"
    OUT_DIR="/mnt/v0rtex-release"
else
    WORK_DIR="/tmp/v0rtex-build-work"
    OUT_DIR="$SCRIPT_DIR/release"
fi

RED='\033[1;31m' GRY='\033[1;37m' WHT='\033[0;37m' DIM='\033[2;37m'
BOLD='\033[1m' RST='\033[0m'

ts()   { date '+%H:%M:%S'; }
log()  { echo -e "${DIM}[$(ts)]${RST} ${GRY}[BUILD]${RST} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${DIM}[$(ts)]${RST} ${WHT}[ OK  ]${RST} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${DIM}[$(ts)]${RST} ${GRY}[WARN ]${RST} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${DIM}[$(ts)]${RST} ${RED}[FAIL ]${RST} $*" | tee -a "$LOG_FILE"; exit 1; }
sec()  {
    echo | tee -a "$LOG_FILE"
    echo -e "${GRY}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}" | tee -a "$LOG_FILE"
    echo -e "${GRY}${BOLD}  $*${RST}" | tee -a "$LOG_FILE"
    echo -e "${GRY}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}" | tee -a "$LOG_FILE"
}

# ════════════════════════════════════════════════
# CI: LIBERAR ESPAÇO NO DISCO (GitHub Actions)
# Remove toolchains e pacotes pré-instalados desnecessários.
# Libera ~20-25 GB no runner ubuntu-latest.
# ════════════════════════════════════════════════
free_ci_disk() {
    [[ "$CI" != "true" ]] && return 0

    sec "LIBERANDO ESPAÇO EM DISCO (CI)"
    log "Espaço antes da limpeza:"
    df -h / /mnt 2>/dev/null | tee -a "$LOG_FILE" || true

    # ── Remover toolchains grandes desnecessários ──────────────────────────
    log "Removendo toolchains pré-instalados..."
    sudo rm -rf \
        /usr/share/dotnet \
        /usr/local/lib/android \
        /opt/ghc \
        /usr/local/share/powershell \
        /usr/share/swift \
        /usr/local/.ghcup \
        /usr/lib/jvm \
        /opt/hostedtoolcache \
        "${AGENT_TOOLSDIRECTORY:-/opt/hostedtoolcache}" \
        /usr/local/share/chromium \
        /usr/local/share/edge_driver \
        /usr/local/share/gecko_driver \
        /usr/share/miniconda \
        /usr/local/share/vcpkg \
        /usr/local/lib/node_modules \
        2>/dev/null || true
    ok "Toolchains removidos"

    # ── Remover pacotes apt desnecessários ────────────────────────────────
    log "Removendo pacotes apt desnecessários..."
    sudo apt-get purge -y \
        '^aspnet.*' '^dotnet.*' '^llvm-[0-9].*' \
        '^php[0-9].*' 'php-common' \
        '^mongodb-.*' '^mysql-.*' '^postgresql-.*' \
        azure-cli google-cloud-cli google-cloud-sdk \
        google-chrome-stable firefox \
        powershell mono-devel libgl1-mesa-dri \
        snapd temurin-* adoptopenjdk-* \
        2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    sudo apt-get clean 2>/dev/null || true
    ok "Pacotes apt limpos"

    # ── Remover imagens Docker ────────────────────────────────────────────
    if command -v docker &>/dev/null; then
        log "Removendo imagens Docker..."
        docker system prune -af 2>/dev/null || true
        ok "Docker limpo"
    fi

    # ── Remover swap do /mnt para liberar espaço lá ──────────────────────
    if swapon --show | grep -q /mnt; then
        log "Removendo swap em /mnt..."
        sudo swapoff /mnt/swapfile 2>/dev/null || true
        sudo rm -f /mnt/swapfile 2>/dev/null || true
        ok "Swap removido"
    fi

    log "Espaço após limpeza:"
    df -h / /mnt 2>/dev/null | tee -a "$LOG_FILE" || true

    local free_mnt
    free_mnt=$(df /mnt --output=avail -BG 2>/dev/null | tail -1 | tr -d 'G ' || echo "0")
    ok "Espaço livre em /mnt: ${free_mnt}GB (work dir do build)"
}

# ════════════════════════════════════════════════
# 0. VALIDAÇÕES INICIAIS
# ════════════════════════════════════════════════
preflight() {
    [[ $EUID -ne 0 ]] && err "Execute como root: sudo bash build.sh"
    [[ "$(uname -s)" != "Linux" ]] && err "Requer Linux (Arch Linux preferido)"

    sec "PRE-FLIGHT CHECKS"
    local deps=(archiso mkarchiso pacman git curl unzip python3 openssl grub)
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

    # ── Gerar profiledef.sh adaptado ao ambiente ─────────────────────────
    # Local: erofs (leitura aleatória ~3× mais rápida, boot mais ágil)
    # CI:    squashfs+zstd nível 3 (consome menos espaço em disco no runner)
    if [[ "$CI" == "true" ]] || ! command -v mkfs.erofs &>/dev/null; then
        [[ "$CI" == "true" ]] && log "CI detectado — usando squashfs (economiza espaço no runner)"
        ! command -v mkfs.erofs &>/dev/null && warn "mkfs.erofs não encontrado — usando squashfs como fallback"
        cat > "$PROFILE_DIR/profiledef.sh" <<'PROFILEDEF'
#!/usr/bin/env bash
# V0rtexOS — ArchISO Profile (CI / squashfs)
iso_name="v0rtex-os"
iso_label="V0RTEX_OS"
iso_publisher="V0rtex Security"
iso_application="V0rtexOS — Grey Hat Linux Hardened"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux'
    'uefi.grub'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=(
    '-comp' 'zstd'
    '-Xcompression-level' '3'
    '-b' '256K'
    '-no-duplicates'
)
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/usr/local/bin/ghost-protocol.sh"]="0:0:755"
    ["/usr/local/bin/aet-scan"]="0:0:755"
    ["/usr/local/bin/aet-nuke"]="0:0:755"
    ["/usr/local/bin/amnesia"]="0:0:755"
    ["/usr/local/bin/install-tools.sh"]="0:0:755"
    ["/usr/local/bin/vortex-center"]="0:0:755"
    ["/usr/local/bin/aeternus-splash"]="0:0:755"
    ["/usr/local/bin/aeternus-panel"]="0:0:755"
    ["/usr/local/bin/aeternus-taskbar"]="0:0:755"
    ["/opt/vortex"]="0:0:755"
    ["/root"]="0:0:700"
    ["/root/.xinitrc"]="0:0:755"
    ["/root/.bash_profile"]="0:0:644"
    ["/root/.zprofile"]="0:0:644"
    ["/usr/local/bin/v0rtex-startx"]="0:0:755"
)
PROFILEDEF
    else
        log "Build local — usando erofs (boot mais rápido, I/O otimizado)"
        cp "$SCRIPT_DIR/archiso/profiledef.sh" "$PROFILE_DIR/profiledef.sh"
    fi
    chmod +x "$PROFILE_DIR/profiledef.sh"
    ok "profiledef.sh configurado"

    # Lista de pacotes
    cp "$SCRIPT_DIR/archiso/packages.x86_64" "$PROFILE_DIR/packages.x86_64"
    local pkg_count
    pkg_count=$(grep -cE "^[^#[:space:]]" "$PROFILE_DIR/packages.x86_64")
    ok "Lista de pacotes: $pkg_count pacotes"

    # Syslinux (boot BIOS) — sobrescreve o releng padrão com o nosso label
    mkdir -p "$PROFILE_DIR/syslinux"
    cp -rT "$SCRIPT_DIR/archiso/syslinux/" "$PROFILE_DIR/syslinux/"
    ok "Syslinux configurado (archisolabel=V0RTEX_OS)"
}

# ════════════════════════════════════════════════
# 3. POPULAR AIROOTFS
# ════════════════════════════════════════════════
populate_airootfs() {
    sec "POPULANDO AIROOTFS"
    local air="$PROFILE_DIR/airootfs"

    # ── 1. Copiar TODA a árvore airootfs de uma vez ───────
    log "Copiando árvore airootfs completa..."
    mkdir -p "$air"
    cp -rT "$SCRIPT_DIR/archiso/airootfs/" "$air/"
    ok "Airootfs base copiado"

    # ── 2. Diretórios extras não cobertos pelo airootfs ───
    mkdir -p \
        "$air/usr/local/bin" \
        "$air/opt/vortex" \
        "$air/opt/wordlists" \
        "$air/opt/cve" \
        "$air/opt/exploits" \
        "$air/opt/scripts" \
        "$air/var/lib/vortex" \
        "$air/var/log/vortex"

    # ── 3. Configs extras de config/ ─────────────────────
    log "Copiando configs extras..."
    install -Dm644 "$SCRIPT_DIR/config/i3/config" \
        "$air/root/.config/i3/config"
    install -Dm644 "$SCRIPT_DIR/config/i3/i3status.conf" \
        "$air/root/.config/i3/i3status.conf"
    install -Dm644 "$SCRIPT_DIR/config/i3/workspace-recon.json" \
        "$air/root/.config/i3/workspace-recon.json"
    install -Dm644 "$SCRIPT_DIR/config/i3/picom.conf" \
        "$air/root/.config/picom/picom.conf"
    install -Dm644 "$SCRIPT_DIR/config/alacritty/alacritty.toml" \
        "$air/root/.config/alacritty/alacritty.toml"
    ok "Configs extras copiados"

    # ── 4. Binários principais ────────────────────────────
    log "Instalando binários principais..."
    install -Dm755 "$SCRIPT_DIR/ghost-protocol/ghost-protocol.sh" \
        "$air/usr/local/bin/ghost-protocol.sh"
    install -Dm755 "$SCRIPT_DIR/justice/aet-scan.py"         "$air/usr/local/bin/aet-scan"
    install -Dm755 "$SCRIPT_DIR/justice/aet-nuke.py"         "$air/usr/local/bin/aet-nuke"
    install -Dm755 "$SCRIPT_DIR/amnesia.sh"                  "$air/usr/local/bin/amnesia"
    install -Dm755 "$SCRIPT_DIR/tools/install-tools.sh"      "$air/usr/local/bin/install-tools"
    install -Dm755 "$SCRIPT_DIR/tools/payload-gen.sh"        "$air/usr/local/bin/payload-gen"
    install -Dm755 "$SCRIPT_DIR/tools/network-attacks.sh"    "$air/usr/local/bin/net-attack"
    install -Dm755 "$SCRIPT_DIR/tools/privesc-linux.sh"      "$air/usr/local/bin/privesc"
    install -Dm755 "$SCRIPT_DIR/tools/web-enum.sh"           "$air/usr/local/bin/web-enum"
    install -Dm755 "$SCRIPT_DIR/tools/ad-attack.sh"          "$air/usr/local/bin/ad-attack"
    install -Dm755 "$SCRIPT_DIR/tools/wireless-attack.sh"    "$air/usr/local/bin/wireless-attack"
    install -Dm755 "$SCRIPT_DIR/tools/post-exploit.sh"       "$air/usr/local/bin/post-exploit"
    install -Dm755 "$SCRIPT_DIR/tools/shell-gen.sh"          "$air/usr/local/bin/shell-gen"
    install -Dm755 "$SCRIPT_DIR/tools/tunnel-setup.sh"       "$air/usr/local/bin/tunnel-setup"
    install -Dm755 "$SCRIPT_DIR/tools/exploit-db-search.py"  "$air/usr/local/bin/exploit-search"
    install -Dm755 "$SCRIPT_DIR/archiso/airootfs/usr/local/bin/mount-squashfs.sh" \
        "$air/usr/local/bin/mount-squashfs.sh"

    # GUI — Centro de Controle GTK3 (Python)
    install -Dm755 "$SCRIPT_DIR/gui/vortex-center.py" \
        "$air/usr/local/bin/vortex-center"
    install -Dm644 "$SCRIPT_DIR/gui/vortex-center.desktop" \
        "$air/usr/share/applications/vortex-center.desktop"
    ok "GUI instalada (vortex-center)"

    # ── GUI C — Splash + Panel + Wallpaper ───────────────
    # Compilar os programas C da GUI Aeternus (Xlib + Cairo)
    if command -v gcc &>/dev/null && pkg-config --exists x11 cairo xrender 2>/dev/null; then
        log "Compilando GUI C (splash, panel, taskbar, wallpaper)..."

        # Use arrays to avoid word-splitting on pkg-config flags
        CFLAGS_GUI=(-O2 -Wall -Wextra -std=c11)
        readarray -t LIBS_X11 < <(pkg-config --libs --cflags x11 cairo xrender | tr ' ' '\n')
        readarray -t LIBS_CAIRO < <(pkg-config --libs --cflags cairo | tr ' ' '\n')

        gcc "${CFLAGS_GUI[@]}" -o /tmp/aeternus-splash \
            "$SCRIPT_DIR/gui/splash/aeternus-splash.c" \
            "${LIBS_X11[@]}" -lm \
            && ok "aeternus-splash compilado" \
            || warn "Falha ao compilar aeternus-splash"

        gcc "${CFLAGS_GUI[@]}" -o /tmp/aeternus-panel \
            "$SCRIPT_DIR/gui/panel/aeternus-panel.c" \
            "${LIBS_X11[@]}" -lm \
            && ok "aeternus-panel compilado" \
            || warn "Falha ao compilar aeternus-panel"

        gcc "${CFLAGS_GUI[@]}" -o /tmp/aeternus-taskbar \
            "$SCRIPT_DIR/gui/panel/aeternus-taskbar.c" \
            "${LIBS_X11[@]}" -lm \
            && ok "aeternus-taskbar compilado" \
            || warn "Falha ao compilar aeternus-taskbar"

        gcc "${CFLAGS_GUI[@]}" -o /tmp/gen-wallpaper \
            "$SCRIPT_DIR/gui/wallpaper/gen-wallpaper.c" \
            "${LIBS_CAIRO[@]}" -lm \
            && ok "gen-wallpaper compilado" \
            || warn "Falha ao compilar gen-wallpaper"

        # Instalar binários compilados no airootfs
        [ -f /tmp/aeternus-splash   ] && \
            install -Dm755 /tmp/aeternus-splash   "$air/usr/local/bin/aeternus-splash"
        [ -f /tmp/aeternus-panel    ] && \
            install -Dm755 /tmp/aeternus-panel    "$air/usr/local/bin/aeternus-panel"
        [ -f /tmp/aeternus-taskbar  ] && \
            install -Dm755 /tmp/aeternus-taskbar  "$air/usr/local/bin/aeternus-taskbar"

        # Gerar wallpaper PNG e instalar
        if [ -f /tmp/gen-wallpaper ]; then
            mkdir -p "$air/usr/local/share/v0rtex"
            /tmp/gen-wallpaper "$air/usr/local/share/v0rtex/wallpaper.png" \
                && ok "Wallpaper gerado em airootfs" \
                || warn "Falha ao gerar wallpaper"
        fi

        ok "GUI C instalada no airootfs"
    else
        warn "gcc ou libcairo/libx11 não encontrado no host — copiando fontes C para compilação no target"
        mkdir -p "$air/usr/local/src/aeternus-gui"
        cp -r "$SCRIPT_DIR/gui/splash"    "$air/usr/local/src/aeternus-gui/"
        cp -r "$SCRIPT_DIR/gui/panel"     "$air/usr/local/src/aeternus-gui/"
        cp -r "$SCRIPT_DIR/gui/wallpaper" "$air/usr/local/src/aeternus-gui/"
        cp    "$SCRIPT_DIR/gui/Makefile"  "$air/usr/local/src/aeternus-gui/"

        # Script de compilação pós-boot
        cat > "$air/usr/local/bin/aeternus-gui-build" << 'GUISCRIPT'
#!/bin/bash
# Compila a GUI V0rtexOS (executar uma vez após instalar pacotes)
# Pacotes necessários: cairo libxrender libx11 gcc make
set -e
SRC=/usr/local/src/aeternus-gui
echo "[v0rtex-gui-build] Verificando dependências..."
pkg-config --exists x11 cairo xrender || {
    echo "[v0rtex-gui-build] Instalando dependências..."
    pacman -S --noconfirm cairo libxrender libx11 gcc make
}
echo "[v0rtex-gui-build] Compilando GUI C (splash, panel, taskbar, wallpaper)..."
make -C "$SRC" all
make -C "$SRC" install PREFIX=/usr/local
echo "[v0rtex-gui-build] Pronto. Execute 'startx' para iniciar o V0rtexOS."
GUISCRIPT
        chmod +x "$air/usr/local/bin/aeternus-gui-build"
        ok "Fontes C da GUI copiadas para $air/usr/local/src/aeternus-gui"
    fi

    # Sempre copiar as fontes C para referência e recompilação
    mkdir -p "$air/usr/local/src/aeternus-gui"
    cp -r "$SCRIPT_DIR/gui/splash"    "$air/usr/local/src/aeternus-gui/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/gui/panel"     "$air/usr/local/src/aeternus-gui/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/gui/wallpaper" "$air/usr/local/src/aeternus-gui/" 2>/dev/null || true
    cp    "$SCRIPT_DIR/gui/Makefile"  "$air/usr/local/src/aeternus-gui/" 2>/dev/null || true

    # ── Rofi — tema V0rtexOS ──────────────────────────────
    log "Instalando tema Rofi V0rtexOS..."
    mkdir -p "$air/root/.config/rofi"
    install -Dm644 "$SCRIPT_DIR/config/rofi/v0rtex.rasi" \
        "$air/root/.config/rofi/v0rtex.rasi"
    install -Dm644 "$SCRIPT_DIR/config/rofi/config.rasi" \
        "$air/root/.config/rofi/config.rasi"
    ok "Rofi tema instalado"

    ok "Binários e configs GUI instalados"

    # ── 5. Serviços systemd ───────────────────────────────
    log "Instalando serviços systemd..."
    install -Dm644 "$SCRIPT_DIR/ghost-protocol/ghost-protocol.service" \
        "$air/etc/systemd/system/ghost-protocol.service"
    install -Dm644 "$SCRIPT_DIR/ghost-protocol/amnesia-shutdown.service" \
        "$air/etc/systemd/system/amnesia-shutdown.service"

    install -Dm644 "$SCRIPT_DIR/archiso/airootfs/etc/systemd/system/mount-squashfs.service" \
        "$air/etc/systemd/system/mount-squashfs.service"
    ok "Serviço mount-squashfs instalado"

    # Habilitar serviços no multi-user.target e sysinit.target
    mkdir -p \
        "$air/etc/systemd/system/multi-user.target.wants" \
        "$air/etc/systemd/system/halt.target.wants" \
        "$air/etc/systemd/system/sysinit.target.wants"

    ln -sf "/etc/systemd/system/mount-squashfs.service" \
        "$air/etc/systemd/system/sysinit.target.wants/mount-squashfs.service" 2>/dev/null || true

    for svc in ghost-protocol aet-nuke NetworkManager tor apparmor; do
        ln -sf "/etc/systemd/system/${svc}.service" \
            "$air/etc/systemd/system/multi-user.target.wants/${svc}.service" 2>/dev/null || true
    done
    ln -sf "/etc/systemd/system/amnesia-shutdown.service" \
        "$air/etc/systemd/system/halt.target.wants/amnesia-shutdown.service" 2>/dev/null || true
    ok "Serviços habilitados"

    # ── Mascarar serviços lentos desnecessários (live ISO) ────
    log "Mascarando serviços desnecessários para boot rápido..."
    mkdir -p "$air/etc/systemd/system"
    local MASK_SVCS=(
        lvm2-monitor.service
        lvm2-lvmpolld.service
        dm-event.service
        mdmon.service
        mdadm.service
        man-db.service
        man-db-cache-update.service
        updatedb.service
        ldconfig.service
        systemd-update-utmp.service
        systemd-update-utmp-runlevel.service
        systemd-update-done.service
        alsa-restore.service
        alsa-state.service
        bluetooth.service
        ModemManager.service
        cups.service
        avahi-daemon.service
        avahi-daemon.socket
        wpa_supplicant.service
        iwd.service
    )
    for svc in "${MASK_SVCS[@]}"; do
        ln -sf /dev/null "$air/etc/systemd/system/${svc}" 2>/dev/null || true
    done
    ok "$(echo "${#MASK_SVCS[@]}" serviços desnecessários mascarados)"

    # ── Zram swap para boot mais rápido (compressão em RAM) ───
    cat > "$air/etc/systemd/zram-generator.conf" <<'ZRAM'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
ZRAM
    ok "Zram swap configurado (lz4/zstd)"

    # ── Systemd journal em RAM — evitar writes lentos ─────────
    mkdir -p "$air/etc/systemd/journald.conf.d"
    cat > "$air/etc/systemd/journald.conf.d/v0rtex.conf" <<'JRN'
[Journal]
Storage=volatile
Compress=yes
SystemMaxUse=64M
RuntimeMaxUse=64M
RateLimitIntervalSec=0
RateLimitBurst=0
JRN
    ok "Journal em RAM configurado"

    ok "Serviços configurados"

    # ── 6. Kernel hardening ───────────────────────────────
    log "Configurando hardening de kernel..."
    install -Dm644 "$SCRIPT_DIR/kernel/hardened.conf" \
        "$air/etc/modprobe.d/v0rtex-blacklist.conf"
    install -Dm644 "$SCRIPT_DIR/kernel/hardened-sysctl.conf" \
        "$air/etc/sysctl.d/99-v0rtex.conf"
    install -Dm644 "$SCRIPT_DIR/kernel/mkinitcpio-hardened.conf" \
        "$air/etc/mkinitcpio.conf"
    ok "Kernel hardening configurado"

    # ── 7. Senha padrão root + autologin no tty1 ──────────
    # Senha padrão: v0rtex
    # Hash gerado com: openssl passwd -6 v0rtex
    local ROOT_HASH='$6$v0rtexOS$8tgAGFSO2RW9fJyTCwsvRGnwcnGNPQGnYdxU3DbVsWkZd.8nq889R4rC5ABr84VGguHbDHcBBvJsQop7zIEs..'

    # Atualiza APENAS a entrada do root no /etc/shadow (não sobrescreve o arquivo inteiro)
    if [[ -f "$air/etc/shadow" ]]; then
        # Arquivo já existe — substitui só o hash do root
        sed -i "s|^root:[^:]*:|root:${ROOT_HASH}:|" "$air/etc/shadow"
    else
        # Arquivo não existe — cria apenas a linha do root
        printf 'root:%s:19800:0:99999:7:::\n' "$ROOT_HASH" > "$air/etc/shadow"
    fi
    chmod 400 "$air/etc/shadow"

    # ── Garante que root usa zsh ────────────────────────────────────────────────
    # A abordagem segura: criar um customize_airootfs.sh que roda em chroot
    # DEPOIS da instalação dos pacotes, via arch-chroot chamado pelo build.sh.
    # Isso evita depender do sed num arquivo que pode não existir no overlay.
    mkdir -p "$air/root"
    cat > "$air/root/customize_airootfs.sh" <<'CUSTSH'
#!/usr/bin/env bash
# Roda em chroot APÓS a instalação dos pacotes pelo mkarchiso
# Chamado explicitamente pelo build.sh

# Garante /etc/shells com entradas corretas
{
    echo /bin/sh
    echo /bin/bash
    echo /usr/bin/bash
    echo /bin/zsh
    echo /usr/bin/zsh
} > /etc/shells

# Define shell do root como zsh
if command -v usermod >/dev/null 2>&1; then
    usermod -s /usr/bin/zsh root 2>/dev/null || \
    usermod -s /bin/zsh root 2>/dev/null || true
fi

# Garante que .bash_profile e .zprofile têm permissão correta
chmod 644 /root/.bash_profile /root/.zprofile 2>/dev/null || true
chmod 755 /root/.xinitrc /usr/local/bin/v0rtex-startx 2>/dev/null || true
CUSTSH
    chmod 755 "$air/root/customize_airootfs.sh"
    ok "Script customize_airootfs.sh criado"

    ok "Senha root definida: v0rtex"

    # Autologin root no tty1 (live ISO — sem prompt de senha)
    mkdir -p "$air/etc/systemd/system/getty@tty1.service.d"
    cat > "$air/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
AUTOLOGIN
    ok "Autologin root em tty1 configurado"

    # REMOVIDO: echo "chsh -s /bin/zsh root" >> profile.d/aeternus.sh
    # Motivo: profile.d roda em CADA login, causando "chsh: Shell not changed"
    # na tela. Shell é definido via customize_airootfs.sh (chroot pós-install)

    cat > "$air/etc/v0rtex-banner" <<'BANNER'
 __   ___  ____  ____  _______  __    ___  ___ 
 \ \ / / \| _ \|_  _||   __\ \/ /   / _ \/ __|
  \ V /| o| v /  | |   | |_  >  <  | |_| \__ \
   \_/ |___|_|_\ |_|  |____/_/\_\  \___/ |___/
                          Grey Hat Linux — Hardened
BANNER

    cat > "$air/etc/motd" <<'MOTD'
╔══════════════════════════════════════════════════════════╗
║  V0rtexOS — Grey Hat Security Distribution              ║
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

    ok "Dotfiles, banner e MOTD configurados"
}

# ════════════════════════════════════════════════
# 4. CUSTOMIZAR BOOTLOADER
# ════════════════════════════════════════════════
configure_boot() {
    sec "CONFIGURANDO BOOTLOADER"

    local air="$PROFILE_DIR/airootfs"

    mkdir -p "$PROFILE_DIR/grub"
    mkdir -p "$air/boot/grub"
    cat > "$PROFILE_DIR/grub/grub.cfg" <<'GRUBCFG'
set default=0
set timeout=1
set timeout_style=countdown
set gfxpayload=keep
insmod all_video
insmod gzio
insmod part_gpt
insmod cryptodisk
insmod luks
insmod gcry_rijndael
insmod gcry_sha256
insmod ext2

menuentry "V0rtexOS" --class v0rtex --class gnu-linux --class gnu --class os {
    linux /arch/boot/x86_64/vmlinuz-linux-hardened \
        archisobasedir=arch \
        archisolabel=V0RTEX_OS \
        cow_spacesize=4G \
        quiet loglevel=0 rd.udev.log_level=3 \
        rd.systemd.show_status=false \
        systemd.show_status=0 \
        vt.handoff=7 \
        apparmor=1 security=apparmor \
        page_poison=1 slab_nomerge \
        pti=on vsyscall=none \
        spectre_v2=on spec_store_bypass_disable=on \
        mitigations=auto,nosmt \
        nowatchdog \
        console=tty0
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
    iso=$(find "$OUT_DIR" -name "v0rtex-os-*.iso" | sort | tail -1)
    [[ -z "$iso" ]] && err "ISO não encontrada em $OUT_DIR"

    local size
    size=$(du -sh "$iso" | cut -f1)
    ok "ISO: $iso ($size)"

    log "Gerando checksums..."
    sha256sum "$iso" > "${iso}.sha256"
    md5sum    "$iso" > "${iso}.md5"
    ok "SHA256: $(cat "${iso}.sha256" | awk '{print $1}')"

    # Em CI a ISO fica em /mnt — copia para $SCRIPT_DIR/release
    # para que o GitHub Actions possa fazer upload como artifact
    if [[ "$CI" == "true" && "$OUT_DIR" != "$SCRIPT_DIR/release" ]]; then
        log "CI: copiando ISO para $SCRIPT_DIR/release (artifact upload)..."
        mkdir -p "$SCRIPT_DIR/release"
        cp -v "$iso" "${iso}.sha256" "${iso}.md5" "$SCRIPT_DIR/release/"
        ok "ISO copiada para $SCRIPT_DIR/release"
    fi

    echo
    echo -e "${WHT}${BOLD}╔═══════════════════════════════════════════════════════╗${RST}"
    echo -e "${WHT}${BOLD}║  V0rtexOS BUILD CONCLUÍDO                            ║${RST}"
    echo -e "${WHT}${BOLD}╠═══════════════════════════════════════════════════════╣${RST}"
    printf "${WHT}${BOLD}║  ISO     : %-43s║${RST}\n" "$(basename "$iso")"
    printf "${WHT}${BOLD}║  Tamanho : %-43s║${RST}\n" "$size"
    printf "${WHT}${BOLD}║  Versão  : %-43s║${RST}\n" "$VORTEX_VERSION"
    echo -e "${WHT}${BOLD}╠═══════════════════════════════════════════════════════╣${RST}"
    echo -e "${WHT}${BOLD}║  Gravar em USB:                                      ║${RST}"
    printf "${WHT}${BOLD}║  sudo dd if=%s of=/dev/sdX bs=4M status=progress ║${RST}\n" "$(basename "$iso")"
    echo -e "${WHT}${BOLD}║  sync                                                ║${RST}"
    echo -e "${WHT}${BOLD}╚═══════════════════════════════════════════════════════╝${RST}"
    echo
    echo -e "${GRY}  Após o boot:${RST}"
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
    echo -e "${GRY}${BOLD}"
    cat <<'HEADER'
 __   ___  ____  ____  _______  __    ___  ___ 
 \ \ / / \| _ \|_  _||   __\ \/ /   / _ \/ __|
  \ V /| o| v /  | |   | |_  >  <  | |_| \__ \
   \_/ |___|_|_\ |_|  |____/_/\_\  \___/ |___/
HEADER
    echo -e "${RST}${GRY}  Grey Hat Linux — Build System v2.0${RST}"
    echo -e "${DIM}  Log: $LOG_FILE${RST}"
    echo

    free_ci_disk
    preflight
    setup_keys
    init_profile
    populate_airootfs
    configure_boot
    build_iso
    post_build
}

main "$@"
