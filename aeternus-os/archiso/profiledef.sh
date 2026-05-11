#!/usr/bin/env bash
# AETERNUS OS — ArchISO Profile Definition
iso_name="aeternus-os"
iso_label="AETERNUS_OS_$(date +%Y%m)"
iso_publisher="AETERNUS Security"
iso_application="AETERNUS OS — Grey Hat Linux Hardened"
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
airootfs_image_type="squashfs"
airootfs_image_tool_options=(
    '-comp' 'zstd'
    '-Xcompression-level' '22'
    '-b' '1M'
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
    ["/opt/aeternus"]="0:0:755"
    ["/root"]="0:0:700"
)
