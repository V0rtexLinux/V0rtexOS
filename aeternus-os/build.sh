#!/usr/bin/env bash
# AETERNUS OS — ArchISO Build Script
# Requer: archiso, sudo, git, curl
# Uso: sudo bash build.sh

set -euo pipefail

PROFILE_DIR="$(pwd)/aeternus-profile"
OUT_DIR="$(pwd)/out"
WORK_DIR="/tmp/aeternus-work"
ARCH="x86_64"

log()  { echo -e "\e[1;36m[AETERNUS]\e[0m $*"; }
ok()   { echo -e "\e[1;32m[  OK  ]\e[0m $*"; }
err()  { echo -e "\e[1;31m[ FAIL ]\e[0m $*"; exit 1; }

# ────────────────────────────────────────────────
# 1. Dependências do host
# ────────────────────────────────────────────────
check_deps() {
    log "Verificando dependências do host..."
    local deps=(archiso mkarchiso pacman git curl iptables)
    for d in "${deps[@]}"; do
        command -v "$d" &>/dev/null || err "Dependência ausente: $d"
    done
    ok "Todas as dependências presentes."
}

# ────────────────────────────────────────────────
# 2. Inicializar perfil a partir do releng oficial
# ────────────────────────────────────────────────
init_profile() {
    log "Inicializando perfil ArchISO..."
    [[ -d "$PROFILE_DIR" ]] && rm -rf "$PROFILE_DIR"
    cp -r /usr/share/archiso/configs/releng "$PROFILE_DIR"
    ok "Perfil copiado de releng."
}

# ────────────────────────────────────────────────
# 3. Repositórios: oficial + BlackArch
# ────────────────────────────────────────────────
configure_repos() {
    log "Configurando repositórios (Arch + BlackArch)..."
    cat > "$PROFILE_DIR/pacman.conf" <<'EOF'
[options]
HoldPkg      = pacman glibc
Architecture = auto
CheckSpace
ParallelDownloads = 8
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[blackarch]
Server = https://mirror.cyberbits.eu/blackarch/$repo/os/$arch
Server = https://blackarch.unixpeople.org/$repo/os/$arch
Server = https://www.blackarch.org/blackarch/$repo/os/$arch
EOF

    # Adicionar chave BlackArch sem interação
    if ! pacman-key --list-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 &>/dev/null; then
        log "Instalando chave GPG do BlackArch..."
        curl -sO https://blackarch.org/strap.sh
        chmod +x strap.sh
        bash strap.sh
        rm -f strap.sh
    fi
    ok "Repositórios configurados."
}

# ────────────────────────────────────────────────
# 4. Lista de pacotes
# ────────────────────────────────────────────────
configure_packages() {
    log "Configurando lista de pacotes..."
    cat > "$PROFILE_DIR/packages.x86_64" <<'EOF'
# ── Base ──────────────────────────────────────
base
base-devel
linux-hardened
linux-hardened-headers
linux-firmware
mkinitcpio
grub
efibootmgr
os-prober

# ── Rede ──────────────────────────────────────
networkmanager
openvpn
wireguard-tools
tor
torsocks
iptables-nft
nftables
iproute2
iputils
net-tools
dnsmasq
dnscrypt-proxy

# ── Shell / Terminal ──────────────────────────
zsh
zsh-completions
zsh-syntax-highlighting
alacritty
tmux
neovim
ranger
bat
fd
ripgrep
fzf
starship

# ── Display / WM ─────────────────────────────
xorg-server
xorg-xinit
xorg-xrandr
i3-wm
i3status
i3lock
picom
dmenu
feh
dunst
xclip
arandr

# ── Segurança base ────────────────────────────
linux-hardened
apparmor
firejail
rkhunter
lynis
fail2ban
ufw

# ── Reconhecimento ───────────────────────────
nmap
masscan
rustscan
amass
subfinder
theHarvester
maltego
recon-ng
gobuster
ffuf
feroxbuster
whatweb

# ── Exploração ────────────────────────────────
metasploit
exploitdb
sqlmap
hydra
hashcat
john
crunch
wordlistctl

# ── Análise de Rede ───────────────────────────
wireshark-qt
tcpdump
bettercap
ettercap
mitmproxy
proxychains-ng
netcat
socat
ncat

# ── Web / Aplicações ─────────────────────────
burpsuite
nikto
wfuzz
dirbuster
nuclei
dalfox

# ── Wireless ─────────────────────────────────
aircrack-ng
airgeddon
wifite
hcxtools
hcxdumptool
kismet
horst

# ── Forense ───────────────────────────────────
autopsy
sleuthkit
binwalk
foremost
volatility3
exiftool

# ── Crypto / Privacidade ──────────────────────
gnupg
cryptsetup
veracrypt
steghide
stegsolve

# ── Dev / Scripting ──────────────────────────
python
python-pip
python-virtualenv
python-scapy
python-requests
python-aiohttp
python-asyncio
go
rust
gcc
gdb
pwndbg
radare2
ghidra

# ── Utilitários ───────────────────────────────
htop
btop
lsof
strace
ltrace
file
curl
wget
rsync
git
p7zip
unzip
sdmem
secure-delete
EOF

    ok "Lista de pacotes gerada."
}

# ────────────────────────────────────────────────
# 5. Copiar arquivos de configuração para airootfs
# ────────────────────────────────────────────────
populate_airootfs() {
    log "Populando airootfs..."
    local air="$PROFILE_DIR/airootfs"

    # Ghost Protocol service
    install -Dm644 ghost-protocol/ghost-protocol.service \
        "$air/etc/systemd/system/ghost-protocol.service"
    install -Dm755 ghost-protocol/ghost-protocol.sh \
        "$air/usr/local/bin/ghost-protocol.sh"

    # Justice binaries
    install -Dm755 justice/aet-scan.py  "$air/usr/local/bin/aet-scan"
    install -Dm755 justice/aet-nuke.py  "$air/usr/local/bin/aet-nuke"

    # Amnésia
    install -Dm755 amnesia.sh "$air/usr/local/bin/amnesia"

    # i3 config
    install -Dm644 config/i3/config         "$air/etc/skel/.config/i3/config"
    install -Dm644 config/alacritty/alacritty.toml \
        "$air/etc/skel/.config/alacritty/alacritty.toml"

    # Habilitar serviços no primeiro boot
    mkdir -p "$air/etc/systemd/system/multi-user.target.wants"
    ln -sf /etc/systemd/system/ghost-protocol.service \
        "$air/etc/systemd/system/multi-user.target.wants/ghost-protocol.service"

    # Configurar hostname e locale
    echo "aeternus" > "$air/etc/hostname"
    cat > "$air/etc/locale.gen" <<'EOF'
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
EOF
    echo "LANG=en_US.UTF-8" > "$air/etc/locale.conf"

    # Personalização do GRUB
    cat > "$air/etc/default/grub" <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="AETERNUS OS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 apparmor=1 security=apparmor page_poison=1 slab_nomerge vsyscall=none"
GRUB_CMDLINE_LINUX=""
EOF

    ok "airootfs populado."
}

# ────────────────────────────────────────────────
# 6. Customizar profiledef.sh
# ────────────────────────────────────────────────
configure_profiledef() {
    cat > "$PROFILE_DIR/profiledef.sh" <<'EOF'
#!/usr/bin/env bash
iso_name="aeternus-os"
iso_label="AETERNUS_OS"
iso_publisher="AETERNUS Security <https://aeternus.local>"
iso_application="AETERNUS OS — Linux Hardened Security Distribution"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-ia32.grub.esp' 'uefi-x64.grub.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '22' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/usr/local/bin/ghost-protocol.sh"]="0:0:755"
  ["/usr/local/bin/aet-scan"]="0:0:755"
  ["/usr/local/bin/aet-nuke"]="0:0:755"
  ["/usr/local/bin/amnesia"]="0:0:755"
)
EOF
    ok "profiledef.sh configurado."
}

# ────────────────────────────────────────────────
# 7. Build final
# ────────────────────────────────────────────────
build_iso() {
    log "Iniciando build da ISO (isso pode levar 15-30 min)..."
    [[ -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    mkdir -p "$OUT_DIR"

    mkarchiso -v \
        -w "$WORK_DIR" \
        -o "$OUT_DIR" \
        "$PROFILE_DIR"

    ok "ISO gerada em: $OUT_DIR"
    ls -lh "$OUT_DIR/"*.iso
}

# ────────────────────────────────────────────────
main() {
    [[ $EUID -ne 0 ]] && err "Execute como root: sudo bash build.sh"
    check_deps
    init_profile
    configure_repos
    configure_packages
    configure_profiledef
    populate_airootfs
    build_iso
}

main "$@"
