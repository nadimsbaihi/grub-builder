# grub-riscv-build Makefile
# Usage:
#   make build          — native cross-compile (needs riscv64 toolchain on host)
#   make docker         — build inside Docker, extract .deb to out/
#   make docker-shell   — drop into the build container for debugging
#   make clean          — remove build artifacts

GRUB_TAG     ?= debian/2.14-2
PKG_VERSION  ?= 2.14
IMAGE_NAME   ?= grub-riscv-builder
OUT_DIR      ?= out

.PHONY: build docker docker-shell clean

# ── Native build ──────────────────────────────────────────────────────────────
build:
	@chmod +x build.sh
	GRUB_TAG=$(GRUB_TAG) PKG_VERSION=$(PKG_VERSION) ./build.sh

build-deb:
	@chmod +x build.sh
	GRUB_TAG=$(GRUB_TAG) PKG_VERSION=$(PKG_VERSION) MAKE_DEB=1 ./build.sh

# ── Docker build ──────────────────────────────────────────────────────────────
docker:
	DOCKER_BUILDKIT=1 docker build \
		--build-arg GRUB_TAG=$(GRUB_TAG) \
		--build-arg PKG_VERSION=$(PKG_VERSION) \
		--output type=local,dest=$(OUT_DIR) \
		-t $(IMAGE_NAME) .
	@echo ">>> Artifacts in $(OUT_DIR)/"

docker-shell:
	docker build --target builder -t $(IMAGE_NAME)-debug .
	docker run --rm -it $(IMAGE_NAME)-debug /bin/bash

# ── Cleanup ───────────────────────────────────────────────────────────────────
clean:
	rm -rf build/ install/ $(OUT_DIR)/
