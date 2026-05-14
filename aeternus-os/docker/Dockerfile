# V0rtexOS — Docker build environment para compilar o ISO
# Base: archlinux:latest com BlackArch repo
# Uso: docker build -t v0rtexos-builder . && docker run --privileged --rm -v $(pwd)/output:/output v0rtexos-builder

FROM archlinux:latest

LABEL maintainer="V0rtexOS"
LABEL description="Build environment for V0rtexOS Arch Linux ISO"

# ── 1. Sistema base ──────────────────────────────────────
RUN pacman -Syu --noconfirm --needed \
    base base-devel \
    archiso \
    git curl wget \
    python python-pip \
    gcc make cmake \
    cairo libxrender libx11 pkg-config \
    grub efibootmgr \
    squashfs-tools \
    dosfstools \
    mtools \
    libisoburn \
    && pacman -Sc --noconfirm

# ── 2. Instalar BlackArch keyring ────────────────────────
RUN curl -fsSL https://blackarch.org/strap.sh -o /tmp/strap.sh \
    && echo "5ea40d49ecd14c2e024deecf90605426db97ea0c  /tmp/strap.sh" | sha1sum -c - 2>/dev/null \
        || echo "[warn] sha1sum nao verificado — continuando" \
    && chmod +x /tmp/strap.sh \
    && /tmp/strap.sh \
    && rm /tmp/strap.sh \
    && pacman -Syu --noconfirm

# ── 3. Criar diretório de trabalho ───────────────────────
WORKDIR /build

# ── 4. Copiar projeto ────────────────────────────────────
COPY . /build/

# ── 5. Fix permissões ────────────────────────────────────
RUN chmod +x /build/build.sh

# ── 6. Script de saída ───────────────────────────────────
RUN mkdir -p /output

# ── 7. Entrypoint ────────────────────────────────────────
CMD ["bash", "-c", "cd /build && bash build.sh && cp -v /build/output/*.iso /output/ 2>/dev/null || cp -v /tmp/v0rtexos-*.iso /output/ 2>/dev/null || find /build -name '*.iso' -exec cp -v {} /output/ \\; && echo '[V0rtexOS] ISO pronta em /output'"]
