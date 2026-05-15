#!/bin/bash
# V0rtexOS — Detecção de Ambiente (VM vs Hardware Real)
# Roda no boot via systemd e escreve /run/v0rtex/env
# Consumido por .xinitrc, vortex-center e outros componentes
#
# Perfis de hardware:
#   full    — Hardware real (picom GLX, efeitos completos)
#   reduced — VM padrão (picom xrender, sombras, sem blur)
#   minimal — VM Android/VectrasVM (sem compositor, mínimo)

set -euo pipefail

OUTDIR=/run/v0rtex
OUTFILE="$OUTDIR/env"
mkdir -p "$OUTDIR"

# ── Detecção primária via systemd-detect-virt ─────────────────────────────────
VIRT="none"
if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
fi

# ── Detecção de DMI / ACPI (fallback se systemd-detect-virt não resolver) ─────
DMI_PRODUCT=$(cat /sys/class/dmi/id/product_name   2>/dev/null || echo "unknown")
DMI_VENDOR=$(cat  /sys/class/dmi/id/sys_vendor      2>/dev/null || echo "unknown")
DMI_VERSION=$(cat /sys/class/dmi/id/product_version 2>/dev/null || echo "unknown")
DMI_BIOS=$(cat    /sys/class/dmi/id/bios_vendor     2>/dev/null || echo "unknown")

# Se systemd-detect-virt falhou, tenta por DMI
if [[ "$VIRT" == "none" ]]; then
    case "${DMI_VENDOR,,}${DMI_PRODUCT,,}${DMI_BIOS,,}" in
        *vmware*)                VIRT="vmware"    ;;
        *virtualbox*|*innotek*) VIRT="oracle"    ;;
        *"bochs"*|*"qemu"*)     VIRT="qemu"      ;;
        *"microsoft corporation"*hv*|*hyper*v*)  VIRT="microsoft" ;;
        *xen*)                  VIRT="xen"       ;;
        *"red hat"*|*kvm*)      VIRT="kvm"       ;;
    esac
fi

# ── Leitura de flags de CPU ───────────────────────────────────────────────────
CPU_FLAGS=$(grep -m1 "^flags" /proc/cpuinfo 2>/dev/null || echo "")
HYPERVISOR_FLAG=0
echo "$CPU_FLAGS" | grep -qw hypervisor && HYPERVISOR_FLAG=1

# ── Detecção específica de Android / VectrasVM ────────────────────────────────
# VectrasVM, Limbo PC, QEMU for Android executam QEMU em cima de Android
ON_ANDROID=0
ANDROID_CLUES=0

# Checar /proc/version por "Android" (kernel customizado Android)
grep -qi android /proc/version 2>/dev/null && ANDROID_CLUES=$((ANDROID_CLUES + 2))

# Checar se existe /proc/android_info (kernel Android puro)
[[ -d /proc/android_info ]] && ANDROID_CLUES=$((ANDROID_CLUES + 3))

# Checar propriedades Android
[[ -f /system/build.prop ]] && ANDROID_CLUES=$((ANDROID_CLUES + 3))
command -v getprop >/dev/null 2>&1 && ANDROID_CLUES=$((ANDROID_CLUES + 3))

# ACPI BIOS de QEMU genérico com RAM muito baixa = sinal de app Android
RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo "0")
if [[ "$VIRT" =~ ^(kvm|qemu|none)$ ]] && [[ "$HYPERVISOR_FLAG" -eq 1 ]]; then
    # VectrasVM costuma alocar 2-4 GB
    [[ "$RAM_MB" -lt 6144 ]] && ANDROID_CLUES=$((ANDROID_CLUES + 1))
fi

# DMI "Standard PC" com BIOS SeaBIOS/QEMU = QEMU no Android
if [[ "${DMI_BIOS,,}" =~ (seabios) ]] && [[ "$VIRT" =~ ^(kvm|qemu|none)$ ]]; then
    ANDROID_CLUES=$((ANDROID_CLUES + 1))
fi

[[ "$ANDROID_CLUES" -ge 3 ]] && ON_ANDROID=1

# ── Resolução de IS_VM e VM_VENDOR ───────────────────────────────────────────
IS_VM=0
VM_VENDOR="hardware"
HW_PROFILE="full"
PICOM_BACKEND="glx"
COMPOSITOR_EFFECTS="full"

case "$VIRT" in
    none)
        if [[ "$HYPERVISOR_FLAG" -eq 1 ]]; then
            # CPU reporta hypervisor mas systemd-detect-virt não reconheceu
            IS_VM=1
            VM_VENDOR="VM Desconhecida"
            HW_PROFILE="reduced"
            PICOM_BACKEND="xrender"
            COMPOSITOR_EFFECTS="reduced"
        else
            IS_VM=0
            VM_VENDOR="Hardware Real"
            HW_PROFILE="full"
        fi
        ;;
    kvm|qemu)
        IS_VM=1
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        if [[ "$ON_ANDROID" -eq 1 ]]; then
            VM_VENDOR="VectrasVM / Android"
            HW_PROFILE="minimal"
            PICOM_BACKEND="none"
            COMPOSITOR_EFFECTS="none"
        else
            VM_VENDOR="QEMU/KVM"
        fi
        ;;
    vmware)
        IS_VM=1
        VM_VENDOR="VMware"
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        ;;
    oracle)
        IS_VM=1
        VM_VENDOR="VirtualBox"
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        ;;
    microsoft)
        IS_VM=1
        VM_VENDOR="Hyper-V"
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        ;;
    xen)
        IS_VM=1
        VM_VENDOR="Xen"
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        ;;
    parallels)
        IS_VM=1
        VM_VENDOR="Parallels"
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        ;;
    docker|lxc|lxc-libvirt|container-other|podman)
        IS_VM=0
        VM_VENDOR="Container ($VIRT)"
        HW_PROFILE="minimal"
        PICOM_BACKEND="none"
        COMPOSITOR_EFFECTS="none"
        ;;
    *)
        IS_VM=1
        VM_VENDOR="VM ($VIRT)"
        HW_PROFILE="reduced"
        PICOM_BACKEND="xrender"
        COMPOSITOR_EFFECTS="reduced"
        ;;
esac

# ── Gravar arquivo de ambiente em /run/v0rtex/env ────────────────────────────
cat > "$OUTFILE" <<EOF
# V0rtexOS — Ambiente detectado no boot
# Gerado por vortex-detect-env em $(date)
VORTEX_IS_VM=$IS_VM
VORTEX_ON_ANDROID=$ON_ANDROID
VORTEX_VIRT_TYPE=$VIRT
VORTEX_VM_VENDOR=$VM_VENDOR
VORTEX_HW_PROFILE=$HW_PROFILE
VORTEX_PICOM_BACKEND=$PICOM_BACKEND
VORTEX_COMPOSITOR_EFFECTS=$COMPOSITOR_EFFECTS
VORTEX_RAM_MB=$RAM_MB
VORTEX_DMI_PRODUCT=$DMI_PRODUCT
VORTEX_DMI_VENDOR=$DMI_VENDOR
EOF

# ── Gerar picom.conf adaptado ao perfil ──────────────────────────────────────
PICOM_RUNTIME=/run/v0rtex/picom.conf

case "$HW_PROFILE" in
    full)
        # Hardware real: GLX com todos os efeitos
        cat > "$PICOM_RUNTIME" <<'PICOMCFG'
backend          = "glx";
glx-no-stencil   = true;
use-damage       = true;
vsync            = true;
shadow           = true;
shadow-radius    = 14;
shadow-offset-x  = -6;
shadow-offset-y  = -6;
shadow-opacity   = 0.55;
shadow-color     = "#000000";
shadow-exclude   = ["name = 'Notification'","class_g = 'i3-frame'","_GTK_FRAME_EXTENTS@:c"];
fading           = true;
fade-in-step     = 0.04;
fade-out-step    = 0.04;
fade-delta       = 4;
active-opacity   = 1.0;
inactive-opacity = 0.92;
frame-opacity    = 0.8;
opacity-rule     = ["95:class_g = 'Alacritty'","88:class_g = 'Alacritty' && !focused","100:class_g = 'firefox'"];
blur-method      = "dual_kawase";
blur-strength    = 7;
blur-background  = true;
corner-radius    = 6;
mark-wmwin-focused      = true;
mark-ovredir-focused    = true;
detect-rounded-corners  = true;
detect-client-opacity   = true;
use-ewmh-active-win     = true;
PICOMCFG
        ;;
    reduced)
        # VM padrão: xrender com sombras, sem blur
        cat > "$PICOM_RUNTIME" <<'PICOMCFG'
backend          = "xrender";
use-damage       = true;
vsync            = true;
shadow           = true;
shadow-radius    = 10;
shadow-offset-x  = -5;
shadow-offset-y  = -5;
shadow-opacity   = 0.45;
shadow-color     = "#000000";
shadow-exclude   = ["name = 'Notification'","class_g = 'i3-frame'","_GTK_FRAME_EXTENTS@:c"];
fading           = true;
fade-in-step     = 0.06;
fade-out-step    = 0.06;
fade-delta       = 6;
active-opacity   = 1.0;
inactive-opacity = 0.95;
frame-opacity    = 0.9;
corner-radius    = 4;
mark-wmwin-focused      = true;
detect-client-opacity   = true;
use-ewmh-active-win     = true;
PICOMCFG
        ;;
    minimal)
        # VectrasVM/Android: sem compositor (arquivo vazio = picom não inicia)
        : > "$PICOM_RUNTIME"
        ;;
esac

# ── Log e notificação ─────────────────────────────────────────────────────────
logger -t vortex-detect-env \
    "Ambiente: IS_VM=$IS_VM VIRT=$VIRT VENDOR='$VM_VENDOR' PROFILE=$HW_PROFILE PICOM=$PICOM_BACKEND"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  V0RTEX — DETECÇÃO DE AMBIENTE                  ║"
echo "╠══════════════════════════════════════════════════╣"
printf "║  %-16s  %-29s ║\n" "Plataforma:"   "$VM_VENDOR"
printf "║  %-16s  %-29s ║\n" "Perfil:"       "$HW_PROFILE"
printf "║  %-16s  %-29s ║\n" "Compositor:"   "$PICOM_BACKEND"
printf "║  %-16s  %-29s ║\n" "RAM:"          "${RAM_MB}MB"
printf "║  %-16s  %-29s ║\n" "DMI Produto:"  "$DMI_PRODUCT"
echo "╚══════════════════════════════════════════════════╝"
echo ""
