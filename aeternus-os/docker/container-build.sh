#!/bin/bash
# V0rtexOS — build da ISO dentro do container Arch (Podman/Docker)
set -euxo pipefail

pacman -Syu --noconfirm --needed \
    archiso git curl base-devel gcc make cmake \
    cairo libxrender libx11 pkg-config \
    squashfs-tools libisoburn dosfstools mtools \
    grub efibootmgr syslinux python openssl haveged

haveged -w 1024 &
pacman-key --init
pacman-key --populate archlinux

curl -fsSL https://blackarch.org/strap.sh -o /tmp/strap.sh
bash /tmp/strap.sh
pacman -Syu --noconfirm

cd /build
export CI=true
export GITHUB_ACTIONS=true
bash build.sh
