FROM debian:trixie-slim AS builder

ARG GRUB_TAG=debian/2.14-2
ARG PKG_VERSION=2.14

ENV DEBIAN_FRONTEND=noninteractive

# ── Build dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf-archive wget git ca-certificates \
        build-essential autoconf automake autopoint \
        gcc-riscv64-linux-gnu \
        bison flex gettext \
        python3 pkg-config \
        ruby ruby-dev rubygems && \
    gem install --no-document fpm && \
    apt-get install -y debhelper patchutils python3 flex bison gawk po-debconf help2man texinfo xfonts-unifont libfreetype-dev gettext libdevmapper-dev libsdl2-dev xorriso cpio parted libfuse3-dev fonts-dejavu-core liblzma-dev liblzo2-dev lzop dosfstools squashfs-tools wamerican pkgconf bash-completion libefiboot-dev libefivar-dev autoconf-archive && \
 rm -rf /var/lib/apt/lists/* 
WORKDIR /src

# ── Copy patches first (layer caching) ───────────────────────────────────────
COPY patches/ patches/

# ── Copy build script ────────────────────────────────────────────────────────
COPY build.sh .
RUN chmod +x build.sh

# ── Build ─────────────────────────────────────────────────────────────────────
RUN GRUB_TAG=${GRUB_TAG} \
    PKG_VERSION=${PKG_VERSION} \
    MAKE_DEB=1 \
    ./build.sh

# ── Output stage — small image with just the artifacts ────────────────────────
FROM scratch AS output
COPY --from=builder /src/build/*.deb /
COPY --from=builder /src/install/ /install/
