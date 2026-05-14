#!/usr/bin/env bash
# V0rtexOS — Docker entrypoint (executa DENTRO do container Arch Linux)
set -euo pipefail

RED='\033[1;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; CYN='\033[0;36m'; RST='\033[0m'
log()  { echo -e "${CYN}[$(date +%H:%M:%S)]${RST} $*"; }
ok()   { echo -e "${GRN}[ OK ]${RST} $*"; }
warn() { echo -e "${YLW}[WARN]${RST} $*"; }
err()  { echo -e "${RED}[FAIL]${RST} $*" >&2; exit 1; }

log "==================================================="
log "  V0rtexOS ISO Builder — Arch Linux Container"
log "  $(date)"
log "==================================================="

# ── 1. Atualizar pacman e sistema base ────────────────
log "Passo 1/5: Atualizando sistema..."
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm --needed 2>&1 | tail -3
ok "Sistema atualizado"

# ── 2. Instalar ferramentas de build ──────────────────
log "Passo 2/5: Instalando ferramentas de compilação..."
pacman -S --noconfirm --needed \
    archiso git curl wget base-devel \
    gcc make cmake nasm \
    cairo libxrender libx11 pkg-config \
    squashfs-tools libisoburn dosfstools mtools \
    grub efibootmgr syslinux \
    python python-pip \
    openssl 2>&1 | tail -5
ok "Ferramentas instaladas"

# ── 3. Configurar BlackArch ───────────────────────────
log "Passo 3/5: Configurando repositório BlackArch..."
if ! grep -q "\[blackarch\]" /etc/pacman.conf 2>/dev/null; then
    # Método mais confiável: adicionar repo manualmente
    # (evita falha do strap.sh em containers)
    curl -fsSL https://blackarch.org/blackarch-mirrorlist -o /etc/pacman.d/blackarch-mirrorlist 2>/dev/null || \
        echo "Server = https://blackarch.org/blackarch/\$arch" > /etc/pacman.d/blackarch-mirrorlist

    # Adicionar chave GPG do BlackArch
    curl -fsSL https://blackarch.org/keytext.txt -o /tmp/blackarch.key 2>/dev/null && \
        pacman-key --add /tmp/blackarch.key && \
        pacman-key --lsign-key 4345771566D76038C7FEB43863EC0ADBEA87E4E3 2>/dev/null || \
        warn "Chave BlackArch não verificada — continuando sem assinatura"

    # Adicionar repo ao pacman.conf
    cat >> /etc/pacman.conf <<'BLACKARCH_REPO'

[blackarch]
Include = /etc/pacman.d/blackarch-mirrorlist
BLACKARCH_REPO

    pacman -Syu --noconfirm 2>&1 | tail -3
    ok "BlackArch configurado"
else
    ok "BlackArch já configurado"
fi

# ── 4. Compilar GUI C (Xlib + Cairo) ─────────────────
log "Passo 4/5: Compilando binários GUI V0rtexOS..."
SRC="/build-src/gui"
CFLAGS=(-O2 -Wall -std=c11)
readarray -t XLIBS < <(pkg-config --libs --cflags x11 cairo xrender | tr ' ' '\n' | grep -v '^$')
readarray -t CAIRLIBS < <(pkg-config --libs --cflags cairo | tr ' ' '\n' | grep -v '^$')

gcc "${CFLAGS[@]}" -o /tmp/aeternus-splash   "$SRC/splash/aeternus-splash.c"   "${XLIBS[@]}" -lm \
    && ok "aeternus-splash compilado" || warn "Falha: aeternus-splash"
gcc "${CFLAGS[@]}" -o /tmp/aeternus-panel    "$SRC/panel/aeternus-panel.c"     "${XLIBS[@]}" -lm \
    && ok "aeternus-panel compilado"  || warn "Falha: aeternus-panel"
gcc "${CFLAGS[@]}" -o /tmp/aeternus-taskbar  "$SRC/panel/aeternus-taskbar.c"   "${XLIBS[@]}" -lm \
    && ok "aeternus-taskbar compilado" || warn "Falha: aeternus-taskbar"
gcc "${CFLAGS[@]}" -o /tmp/gen-wallpaper     "$SRC/wallpaper/gen-wallpaper.c"  "${CAIRLIBS[@]}" -lm \
    && ok "gen-wallpaper compilado"   || warn "Falha: gen-wallpaper"

# ── 5. Montar profile e rodar mkarchiso ───────────────
log "Passo 5/5: Construindo ISO com mkarchiso..."
log "Isso pode levar 30-90 minutos. Acompanhe os logs abaixo."

WORK_DIR="/tmp/v0rtex-work"
OUT_DIR="/output"
PROFILE_DIR="/tmp/v0rtex-profile"
AIR="$PROFILE_DIR/airootfs"

mkdir -p "$WORK_DIR" "$OUT_DIR" "$PROFILE_DIR"

# Copiar archiso profile base
cp -r /build-src/archiso/. "$PROFILE_DIR/"

# Copiar configs customizadas
mkdir -p "$AIR/root/.config/rofi"
cp -r /build-src/config/rofi/. "$AIR/root/.config/rofi/" 2>/dev/null || true
mkdir -p "$AIR/root/.config/i3"
cp -r /build-src/config/i3/. "$AIR/root/.config/i3/" 2>/dev/null || true
mkdir -p "$AIR/root/.config/alacritty"
cp -r /build-src/config/alacritty/. "$AIR/root/.config/alacritty/" 2>/dev/null || true

# Instalar binários GUI compilados
for bin in aeternus-splash aeternus-panel aeternus-taskbar; do
    [ -f "/tmp/$bin" ] && install -Dm755 "/tmp/$bin" "$AIR/usr/local/bin/$bin"
done

# Copiar fontes C para recompilação no target
mkdir -p "$AIR/usr/local/src/aeternus-gui"
cp -r /build-src/gui/. "$AIR/usr/local/src/aeternus-gui/" 2>/dev/null || true

# Gerar wallpaper
mkdir -p "$AIR/usr/local/share/v0rtex"
[ -f /tmp/gen-wallpaper ] && \
    /tmp/gen-wallpaper "$AIR/usr/local/share/v0rtex/wallpaper.png" 2>/dev/null || true

# Verificar se profiledef.sh existe
[[ ! -f "$PROFILE_DIR/profiledef.sh" ]] && \
    err "profiledef.sh não encontrado em $PROFILE_DIR"

log "Iniciando mkarchiso..."
echo "────────────────────────────────────────────────────"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR" 2>&1

echo "────────────────────────────────────────────────────"

# ── Resultado ─────────────────────────────────────────
ISO=$(find "$OUT_DIR" -name "*.iso" 2>/dev/null | head -1)
if [[ -n "$ISO" ]]; then
    SIZE=$(du -sh "$ISO" | cut -f1)
    ok "==================================================="
    ok "  V0RTEX OS — ISO GERADA COM SUCESSO!"
    ok "  Arquivo : $ISO"
    ok "  Tamanho : $SIZE"
    ok "  SHA256  : $(sha256sum "$ISO" | cut -d' ' -f1)"
    ok "==================================================="
    ls -lh "$OUT_DIR/"
else
    err "ISO não foi gerada. Verifique os logs acima."
fi
