#!/usr/bin/env bash
# V0rtexOS — ArchISO Profile Definition
# NOTE: Este arquivo é o padrão para builds locais (erofs).
# Em CI, o build.sh gera uma versão adaptada (squashfs) para economizar espaço.
iso_name="v0rtex-os"
iso_label="V0RTEX_OS"
iso_publisher="V0rtex Security"
iso_application="V0rtexOS — Grey Hat Linux Hardened"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-ia32.grub.esp'
    'uefi-x64.grub.esp'
)
arch="x86_64"
pacman_conf="pacman.conf"

# ── Filesystem da imagem ──────────────────────────────────────────────────────
# erofs: filesystem read-only moderno (kernel 4.19+)
#   · Leitura aleatória ~3× mais rápida que squashfs
#   · Suporte a dedup de blocos e compressão zstd nativa
#   · Ideal para live ISO: boot mais rápido, menor latência de I/O
# Fallback para squashfs em builds CI (veja build.sh)
airootfs_image_type="erofs"
airootfs_image_tool_options=(
    '--compress=zstd,level=5'
    '--block-size=4096'
    '--dedupe'
    '--all-root'
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
)
