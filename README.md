# grub-riscv-build

Cross-compile GRUB for RISC-V EFI with SpacemiT / Milk-V Jupiter patches.

## Patches

| File | Description |
|------|-------------|
| `0001-sync-bianbu-25.04.patch` | SpacemiT Bianbu 25.04 sync — adds `efivariable` module, fixes `fshelp` iteration, improves EFI Linux loader and `os-prober` detection |

This patch targets **GRUB 2.14** (the version used in Debian Trixie / Ubuntu).

## Quick start

### Option A — Docker (recommended, no host toolchain needed)

```bash
make docker          # builds and extracts .deb + install tree to out/
ls out/*.deb
```

### Option B — Native cross-compile (Arch / Debian host)

Install dependencies:

```bash
# Debian / Ubuntu
sudo apt install git build-essential autoconf automake \
    gcc-riscv64-linux-gnu bison flex gettext python3

# Arch
sudo pacman -S git base-devel riscv64-linux-gnu-gcc bison flex
```

Then build:

```bash
make build           # compile only
make build-deb       # compile + package .deb (needs `fpm`)
```

## Configuration

All tunables are environment variables (or Makefile overrides):

| Variable | Default | Description |
|----------|---------|-------------|
| `GRUB_TAG` | `grub-2.14` | Git tag to check out from upstream |
| `PKG_VERSION` | `2.14` | Version string for the `.deb` |
| `PKG_NAME` | `grub-spacemit` | Package name |
| `CROSS_PREFIX` | `riscv64-linux-gnu` | Toolchain triplet |
| `MAKE_DEB` | `0` | Set `1` to build a `.deb` |
| `JOBS` | `$(nproc)` | Parallel make jobs |

## Adding more patches

Drop any `.patch` file into `patches/`. They are applied in lexicographic order, so use the `NNNN-description.patch` naming convention.

## Output

After a successful build:

- **`install/`** — staged install tree (GRUB binaries, modules, `grub-mkimage`, etc.)
- **`build/*.deb`** — Debian package (if `MAKE_DEB=1`)

## License

GRUB is licensed under GPLv3+. Patches carry their original authorship and licensing.
