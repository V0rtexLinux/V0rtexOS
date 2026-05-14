#!/usr/bin/env bash
# V0rtexOS — Script para compilar o ISO usando Docker
# Uso: bash docker/run-build.sh
# Requer: docker instalado e rodando

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/output"
IMAGE_NAME="v0rtexos-builder"
CONTAINER_NAME="v0rtexos-build-$$"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[BUILD]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*" >&2; }

log "V0rtexOS ISO Builder via Docker"
log "================================"

# ── Verificar Docker ─────────────────────────────────────
if ! command -v docker &>/dev/null; then
    err "Docker não encontrado. Instale Docker e tente novamente."
    exit 1
fi
if ! docker info &>/dev/null; then
    err "Docker daemon não está rodando."
    err "Tente: sudo systemctl start docker"
    exit 1
fi
ok "Docker disponível: $(docker --version)"

# ── Criar diretório de saída ─────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Build da imagem Docker ───────────────────────────────
log "Construindo imagem Docker (isso pode demorar na primeira vez)..."
docker build \
    --no-cache \
    --progress=plain \
    -t "$IMAGE_NAME" \
    -f "$SCRIPT_DIR/Dockerfile" \
    "$PROJECT_ROOT" \
    2>&1 | tee "$OUTPUT_DIR/docker-build.log"

ok "Imagem Docker construída: $IMAGE_NAME"

# ── Compilar o ISO dentro do container ──────────────────
log "Iniciando compilação do ISO (pode demorar 30-90 min)..."
log "Logs em tempo real abaixo:"
echo "──────────────────────────────────────────────────────"

docker run \
    --privileged \
    --rm \
    --name "$CONTAINER_NAME" \
    -v "$OUTPUT_DIR:/output" \
    -v /dev:/dev \
    --cap-add=ALL \
    "$IMAGE_NAME" \
    2>&1 | tee -a "$OUTPUT_DIR/iso-build.log"

echo "──────────────────────────────────────────────────────"

# ── Verificar resultado ──────────────────────────────────
ISO_FILE=$(find "$OUTPUT_DIR" -name "*.iso" -newer "$OUTPUT_DIR/docker-build.log" 2>/dev/null | head -1)
if [ -n "$ISO_FILE" ]; then
    SIZE=$(du -sh "$ISO_FILE" | cut -f1)
    ok "ISO gerada com sucesso!"
    ok "Arquivo: $ISO_FILE"
    ok "Tamanho: $SIZE"
    echo ""
    echo "Para testar com QEMU:"
    echo "  qemu-system-x86_64 -boot d -cdrom '$ISO_FILE' -m 2048 -enable-kvm"
else
    warn "ISO não encontrada em $OUTPUT_DIR"
    warn "Verifique o log: $OUTPUT_DIR/iso-build.log"
    exit 1
fi
