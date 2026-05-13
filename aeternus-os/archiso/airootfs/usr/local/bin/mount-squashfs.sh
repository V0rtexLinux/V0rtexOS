#!/usr/bin/env bash
# V0rtexOS — Monta o airootfs squashfs no boot do live ISO
# Executado automaticamente pelo mount-squashfs.service

set -euo pipefail

MOUNT_POINT="/run/archiso/airootfs"
SQUASHFS_MODULE="squashfs"

log()  { echo "[mount-squashfs] $*"; }
err()  { echo "[mount-squashfs] ERRO: $*" >&2; }

# ── 1. Carregar módulo squashfs ──────────────────────────────
log "Carregando módulo $SQUASHFS_MODULE..."
if ! modprobe "$SQUASHFS_MODULE"; then
    err "Falha ao carregar módulo $SQUASHFS_MODULE"
    exit 1
fi
log "Módulo $SQUASHFS_MODULE carregado."

# ── 2. Criar ponto de montagem se necessário ────────────────
mkdir -p "$MOUNT_POINT"

# ── 3. Tentar montar via /dev/loop0 primeiro ────────────────
log "Tentando: mount -t squashfs /dev/loop0 $MOUNT_POINT"
if mount -t squashfs /dev/loop0 "$MOUNT_POINT" 2>/dev/null; then
    log "Montado com sucesso em /dev/loop0 -> $MOUNT_POINT"
    exit 0
fi

# ── 4. Fallback: detectar dispositivo loop correto ──────────
err "/dev/loop0 falhou. Listando dispositivos loop disponíveis..."
losetup -a

LOOP_DEV=""
while IFS= read -r line; do
    dev=$(echo "$line" | awk -F: '{print $1}')
    if [[ -b "$dev" ]]; then
        LOOP_DEV="$dev"
        break
    fi
done < <(losetup -a)

if [[ -z "$LOOP_DEV" ]]; then
    err "Nenhum dispositivo loop encontrado. Abortando."
    losetup -a
    exit 1
fi

log "Dispositivo loop detectado: $LOOP_DEV"
log "Tentando: mount -t squashfs $LOOP_DEV $MOUNT_POINT"

if mount -t squashfs "$LOOP_DEV" "$MOUNT_POINT"; then
    log "Montado com sucesso em $LOOP_DEV -> $MOUNT_POINT"
    exit 0
fi

err "Falha ao montar squashfs com $LOOP_DEV. Dispositivos loop disponíveis:"
losetup -a
exit 1
