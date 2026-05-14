#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  V0rtexOS — COMPILAR ISO (rodar em Arch Linux ou Docker)
#  Uso: bash COMPILE-ISO.sh
#  Requer: Arch Linux nativo OU Docker instalado
# ══════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[1;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYN='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_OUTPUT="$SCRIPT_DIR/iso-output"
mkdir -p "$ISO_OUTPUT"

log()  { echo -e "\n${CYN}${BLD}▶ $*${RST}"; }
ok()   { echo -e "${GRN}✓ $*${RST}"; }
warn() { echo -e "${YLW}⚠ $*${RST}"; }
err()  { echo -e "${RED}✗ $*${RST}" >&2; exit 1; }

echo -e "${BLD}"
echo "  ██╗   ██╗ ██████╗ ██████╗ ████████╗███████╗██╗  ██╗"
echo "  ██║   ██║██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝╚██╗██╔╝"
echo "  ██║   ██║██║   ██║██████╔╝   ██║   █████╗   ╚███╔╝ "
echo "  ╚██╗ ██╔╝██║   ██║██╔══██╗   ██║   ██╔══╝   ██╔██╗ "
echo "   ╚████╔╝ ╚██████╔╝██║  ██║   ██║   ███████╗██╔╝ ██╗"
echo "    ╚═══╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝"
echo -e "  ${CYN}ISO Builder${RST}${BLD} — V0rtexOS Grey Hat Security${RST}"
echo ""

# ── Detectar método de build ──────────────────────────────────
METHOD=""

if command -v pacman &>/dev/null && [ -f /etc/arch-release ]; then
    METHOD="arch-native"
    ok "Arch Linux detectado — build nativo"
elif command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    METHOD="docker"
    ok "Docker detectado — build via container"
elif command -v podman &>/dev/null; then
    METHOD="podman"
    ok "Podman detectado — build via container"
else
    err "Nenhum método de build disponível.
  Opções:
  1. Rodar em Arch Linux (nativo ou VM)
  2. Instalar Docker: https://docs.docker.com/get-docker/
  3. Usar GitHub Actions: push para GitHub e o CI compila automaticamente
     (workflow já está em .github/workflows/build-iso.yml)"
fi

echo ""

# ════════════════════════════════════════════════════
# MÉTODO 1 — Arch Linux Nativo
# ════════════════════════════════════════════════════
build_arch_native() {
    log "Compilando em Arch Linux nativo..."

    [[ $EUID -ne 0 ]] && err "Build nativo requer root: sudo bash COMPILE-ISO.sh"

    # Instalar dependências
    log "Instalando dependências..."
    pacman -Syu --noconfirm --needed \
        archiso git curl base-devel \
        gcc make cairo libxrender libx11 pkg-config \
        squashfs-tools libisoburn dosfstools mtools \
        grub efibootmgr

    # BlackArch repo (se não configurado)
    if ! grep -q "\[blackarch\]" /etc/pacman.conf; then
        log "Configurando BlackArch..."
        curl -fsSL https://blackarch.org/strap.sh -o /tmp/strap.sh
        chmod +x /tmp/strap.sh && bash /tmp/strap.sh && rm /tmp/strap.sh
    fi

    # Compilar GUI
    _compile_gui

    # Rodar build principal
    log "Executando build.sh..."
    bash "$SCRIPT_DIR/build.sh"

    _show_result
}

# ════════════════════════════════════════════════════
# MÉTODO 2 — Docker
# ════════════════════════════════════════════════════
build_docker() {
    local DOCKER_CMD="${1:-docker}"
    log "Compilando via $DOCKER_CMD (container Arch Linux)..."

    # Verificar espaço (ISO build precisa ~20GB)
    local FREE_GB
    FREE_GB=$(df "$ISO_OUTPUT" --output=avail -BG 2>/dev/null | tail -1 | tr -d 'G ' || echo "99")
    if [ "$FREE_GB" -lt 15 ]; then
        warn "Menos de 15GB livres ($FREE_GB GB). Build pode falhar."
    fi

    # Criar entrypoint inline para o container
    cat > /tmp/v0rtex-docker-entry.sh << 'DOCKER_ENTRY'
#!/bin/bash
set -euo pipefail
RED='\033[1;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; RST='\033[0m'
log()  { echo -e "${CYN}[$(date +%H:%M:%S)]${RST} $*"; }
ok()   { echo -e "${GRN}[ OK ]${RST} $*"; }

log "Atualizando sistema Arch..."
pacman-key --init && pacman-key --populate archlinux
pacman -Syu --noconfirm --needed 2>&1 | tail -3

log "Instalando archiso e dependências..."
pacman -S --noconfirm --needed \
    archiso git curl base-devel gcc make cmake \
    cairo libxrender libx11 pkg-config \
    squashfs-tools libisoburn dosfstools mtools \
    grub efibootmgr syslinux python openssl 2>&1 | tail -5

log "Configurando BlackArch..."
curl -fsSL https://blackarch.org/strap.sh -o /tmp/strap.sh
chmod +x /tmp/strap.sh && bash /tmp/strap.sh 2>&1 | tail -10 && rm /tmp/strap.sh
pacman -Syu --noconfirm 2>&1 | tail -3

log "Compilando GUI V0rtexOS (C/Xlib/Cairo)..."
SRC="/project/gui"
CFLAGS="-O2 -Wall -std=c11"
XLIBS="$(pkg-config --libs --cflags x11 cairo xrender)"
CAIRLIBS="$(pkg-config --libs --cflags cairo)"
gcc $CFLAGS -o /usr/local/bin/aeternus-splash   "$SRC/splash/aeternus-splash.c"   $XLIBS -lm   && ok splash
gcc $CFLAGS -o /usr/local/bin/aeternus-panel    "$SRC/panel/aeternus-panel.c"     $XLIBS -lm   && ok panel
gcc $CFLAGS -o /usr/local/bin/aeternus-taskbar  "$SRC/panel/aeternus-taskbar.c"   $XLIBS -lm   && ok taskbar
gcc $CFLAGS -o /tmp/gen-wallpaper               "$SRC/wallpaper/gen-wallpaper.c"  $CAIRLIBS -lm && ok wallpaper

log "Preparando perfil archiso..."
PROFILE="/tmp/v0rtex-profile"
AIR="$PROFILE/airootfs"
cp -r /project/archiso/. "$PROFILE/"
mkdir -p "$AIR/root/.config/rofi"
cp -r /project/config/rofi/. "$AIR/root/.config/rofi/" 2>/dev/null || true
mkdir -p "$AIR/root/.config/i3"
cp -r /project/config/i3/. "$AIR/root/.config/i3/" 2>/dev/null || true
mkdir -p "$AIR/root/.config/alacritty"
cp -r /project/config/alacritty/. "$AIR/root/.config/alacritty/" 2>/dev/null || true
for bin in aeternus-splash aeternus-panel aeternus-taskbar; do
    install -Dm755 "/usr/local/bin/$bin" "$AIR/usr/local/bin/$bin" 2>/dev/null || true
done
mkdir -p "$AIR/usr/local/src/aeternus-gui" "$AIR/usr/local/share/v0rtex"
cp -r /project/gui/. "$AIR/usr/local/src/aeternus-gui/" 2>/dev/null || true
[ -f /tmp/gen-wallpaper ] && /tmp/gen-wallpaper "$AIR/usr/local/share/v0rtex/wallpaper.png" 2>/dev/null || true

log "Iniciando mkarchiso (30-90 min)..."
mkdir -p /tmp/v0rtex-work /output
mkarchiso -v -w /tmp/v0rtex-work -o /output "$PROFILE" 2>&1

ISO=$(find /output -name "*.iso" | head -1)
if [ -n "$ISO" ]; then
    VERSION=$(date +%Y%m%d)
    mv "$ISO" "/output/V0rtexOS-${VERSION}-x86_64.iso"
    sha256sum "/output/V0rtexOS-${VERSION}-x86_64.iso" > "/output/SHA256SUMS"
    ok "================================================"
    ok "  V0rtexOS ISO GERADA COM SUCESSO!"
    ok "  $(ls -lh /output/*.iso)"
    ok "  SHA256: $(cat /output/SHA256SUMS | cut -d' ' -f1)"
    ok "================================================"
else
    echo "ERRO: ISO não gerada" >&2; exit 1
fi
DOCKER_ENTRY
    chmod +x /tmp/v0rtex-docker-entry.sh

    log "Iniciando container Arch Linux (precisa de --privileged)..."
    log "Isso baixará ~4-8GB de pacotes. Pode levar 30-90 minutos."
    echo ""

    $DOCKER_CMD run \
        --privileged \
        --rm \
        --name "v0rtexos-build-$$" \
        -v "$SCRIPT_DIR:/project:ro" \
        -v "$ISO_OUTPUT:/output" \
        -v "/tmp/v0rtex-docker-entry.sh:/entrypoint.sh:ro" \
        -e TERM=xterm \
        archlinux:latest \
        bash /entrypoint.sh

    _show_result
}

# ── Funções auxiliares ────────────────────────────────────────
_compile_gui() {
    log "Compilando binários GUI..."
    SRC="$SCRIPT_DIR/gui"
    CF="-O2 -Wall -std=c11"
    XL=$(pkg-config --libs --cflags x11 cairo xrender)
    CL=$(pkg-config --libs --cflags cairo)
    gcc $CF -o "$SCRIPT_DIR/archiso/airootfs/usr/local/bin/aeternus-splash"   "$SRC/splash/aeternus-splash.c"   $XL -lm
    gcc $CF -o "$SCRIPT_DIR/archiso/airootfs/usr/local/bin/aeternus-panel"    "$SRC/panel/aeternus-panel.c"     $XL -lm
    gcc $CF -o "$SCRIPT_DIR/archiso/airootfs/usr/local/bin/aeternus-taskbar"  "$SRC/panel/aeternus-taskbar.c"   $XL -lm
    gcc $CF -o /tmp/gen-wallpaper                                               "$SRC/wallpaper/gen-wallpaper.c" $CL -lm
    mkdir -p "$SCRIPT_DIR/archiso/airootfs/usr/local/share/v0rtex"
    /tmp/gen-wallpaper "$SCRIPT_DIR/archiso/airootfs/usr/local/share/v0rtex/wallpaper.png"
    ok "GUI compilada"
}

_show_result() {
    echo ""
    ISO=$(find "$ISO_OUTPUT" -name "*.iso" 2>/dev/null | head -1)
    if [ -n "$ISO" ]; then
        SIZE=$(du -sh "$ISO" | cut -f1)
        SHA=$(sha256sum "$ISO" 2>/dev/null | cut -d' ' -f1 | head -c 16)
        echo -e "${GRN}${BLD}"
        echo "  ╔═══════════════════════════════════════════════╗"
        echo "  ║        V0RTEX OS — ISO PRONTA!               ║"
        echo "  ╠═══════════════════════════════════════════════╣"
        echo "  ║  Arquivo: $(basename "$ISO")"
        printf "  ║  Tamanho: %-36s║\n" "$SIZE"
        printf "  ║  SHA256:  %-36s║\n" "${SHA}..."
        echo "  ╠═══════════════════════════════════════════════╣"
        echo "  ║  Gravar USB:                                  ║"
        echo "  ║  sudo dd if=$ISO                              ║"
        echo "  ║       of=/dev/sdX bs=4M status=progress       ║"
        echo "  ╠═══════════════════════════════════════════════╣"
        echo "  ║  Testar QEMU:                                 ║"
        echo "  ║  qemu-system-x86_64 -boot d \\                ║"
        echo "  ║    -cdrom $ISO \\                              ║"
        echo "  ║    -m 4096 -enable-kvm                        ║"
        echo "  ╚═══════════════════════════════════════════════╝"
        echo -e "${RST}"
    else
        warn "ISO não encontrada em $ISO_OUTPUT"
    fi
}

# ── Executar método detectado ─────────────────────────────────
case "$METHOD" in
    arch-native) build_arch_native ;;
    docker)      build_docker "docker" ;;
    podman)      build_docker "podman" ;;
esac
