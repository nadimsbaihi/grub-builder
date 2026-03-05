#!/usr/bin/env bash
#
# build.sh — Clone GRUB, apply SpacemiT/RISC-V patches, cross-compile for riscv64 EFI,
#             and optionally package as a .deb.
#
set -euo pipefail

# ── Configurable variables ────────────────────────────────────────────────────
GRUB_REPO="${GRUB_REPO:-https://salsa.debian.org/grub-team/grub.git}"
GRUB_TAG="${GRUB_TAG:-debian/2.14-2}"          # upstream tag to base patches on
BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"
INSTALL_DIR="${INSTALL_DIR:-$(pwd)/install}"
PATCH_DIR="${PATCH_DIR:-$(pwd)/patches}"
JOBS="${JOBS:-$(nproc)}"
PKG_VERSION="${PKG_VERSION:-2.14}"
PKG_NAME="${PKG_NAME:-grub-spacemit}"
CROSS_PREFIX="${CROSS_PREFIX:-riscv64-linux-gnu}"
MAKE_DEB="${MAKE_DEB:-1}"                  # set to 1 to build a .deb with fpm

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { printf '\033[1;34m>>> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

check_deps() {
    local missing=()
    for cmd in git make autoreconf "${CROSS_PREFIX}-gcc"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if (( ${#missing[@]} )); then
        die "Missing dependencies: ${missing[*]}
On Debian/Ubuntu:  apt install git build-essential autoconf automake \
gcc-riscv64-linux-gnu bison flex gettext
On Arch:           pacman -S git base-devel riscv64-linux-gnu-gcc bison flex"
    fi
}

# ── 1. Clone / update source ─────────────────────────────────────────────────
clone_source() {
    log "Cloning GRUB from ${GRUB_REPO} (tag: ${GRUB_TAG})"
    if [[ -d "${BUILD_DIR}/grub/.git" ]]; then
        log "Source tree exists — resetting to ${GRUB_TAG}"
        git -C "${BUILD_DIR}/grub" fetch --tags
        git -C "${BUILD_DIR}/grub" checkout "${GRUB_TAG}"
        git -C "${BUILD_DIR}/grub" reset --hard "${GRUB_TAG}"
    else
        mkdir -p "${BUILD_DIR}"
        git clone --depth 50 --branch "${GRUB_TAG}" "${GRUB_REPO}" "${BUILD_DIR}/grub"
    fi
}

# ── 2. Apply patches ─────────────────────────────────────────────────────────
apply_patches() {
    log "Applying patches from ${PATCH_DIR}"
    cd "${BUILD_DIR}/grub"

    # Reset any previously applied patches so the script is idempotent
    git checkout -- . 2>/dev/null || true

    for p in "${PATCH_DIR}"/*.patch; do
        [[ -f "$p" ]] || continue
        local name
        name="$(basename "$p")"
        if git apply --check "$p" 2>/dev/null; then
            log "  Applying ${name}"
            git apply "$p"
        else
            log "  Applying ${name} (falling back to patch -p1)"
            patch -p1 --forward --no-backup-if-mismatch < "$p" || \
                die "Patch ${name} failed to apply"
        fi
    done
}

# ── 3. Configure ──────────────────────────────────────────────────────────────
configure_grub() {
    log "Running bootstrap + configure"
    cd "${BUILD_DIR}/grub"

    # GRUB ships a bootstrap script that calls autoreconf
    if [[ -x ./bootstrap ]]; then
        ./bootstrap
    else
        autoreconf -fi
    fi

    ./configure \
        --target="${CROSS_PREFIX}" \
        --with-platform=efi \
        --disable-werror \
        --prefix=/usr \
        --libdir=/usr/lib
}

# ── 4. Build ──────────────────────────────────────────────────────────────────
build_grub() {
    log "Building GRUB (jobs=${JOBS})"
    cd "${BUILD_DIR}/grub"
    make -j"${JOBS}"
}

# ── 5. Install into staging tree ──────────────────────────────────────────────
install_grub() {
    log "Installing to ${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}"
    cd "${BUILD_DIR}/grub"
    make install DESTDIR="${INSTALL_DIR}"
}

# ── 6. (Optional) Package as .deb ────────────────────────────────────────────
package_deb() {
    if [[ "${MAKE_DEB}" != "1" ]]; then
        log "Skipping .deb packaging (set MAKE_DEB=1 to enable)"
        return
    fi
    command -v fpm &>/dev/null || die "fpm not found — gem install fpm"
    log "Packaging ${PKG_NAME}_${PKG_VERSION}_riscv64.deb"
    fpm -s dir -t deb \
        -n "${PKG_NAME}" \
        -a riscv64 \
        -v "${PKG_VERSION}" \
        -C "${INSTALL_DIR}" \
        --description "Custom GRUB build for RISC-V (SpacemiT patches)" \
        --maintainer "$(git config user.name) <$(git config user.email)>" \
        .
    mv ./*.deb "${BUILD_DIR}/" 2>/dev/null || true
    log "Package written to ${BUILD_DIR}/"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    check_deps
    clone_source
    apply_patches
    configure_grub
    build_grub
    install_grub
    package_deb
    log "Done.  Staged install tree: ${INSTALL_DIR}"
}

main "$@"
