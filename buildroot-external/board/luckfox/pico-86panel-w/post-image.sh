#!/usr/bin/env bash
#
# post-image.sh — Luckfox Pico 86Panel W
#
# Called by buildroot after all images have been built.
# Assembles the Rockchip-specific firmware artifacts:
#
#   idblock.img    — IDB-format loader block (written to idblock eMMC partition)
#   download.bin   — full loader (DDR + USB plug + SPL), uploaded over USB during flash
#   uboot.img      — U-Boot FIT image (written to uboot eMMC partition)
#   boot.img       — kernel FIT image containing zImage + DTB
#   env.img        — partition table / U-Boot environment (32K)
#   update.img     — single-file Rockchip firmware package (all of the above)
#
# Prerequisites:
#   - afptool, rkImageMaker  (vendored in board/luckfox/pico-86panel-w/tools/)
#   - boot_merger, resource_tool (installed by rockchip-rkbin package into HOST_DIR)
#   - rkbin blobs and INI files (installed by rockchip-rkbin into STAGING_DIR/rkbin/)
#
# Usage: called automatically by buildroot — do not run directly.
#   BINARIES_DIR  set by buildroot to <output>/images/
#   BR2_EXTERNAL_LUCKFOX_86PANEL_PATH set by buildroot from external.desc name

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# BR2_EXTERNAL_LUCKFOX_86PANEL_PATH is set by Buildroot to the absolute path of
# buildroot-external/.  Fall back to relative computation for manual runs.
EXTERNAL_DIR="${BR2_EXTERNAL_LUCKFOX_86PANEL_PATH:-$(cd "${SCRIPT_DIR}/../../.." && pwd)}"

BINARIES="${BINARIES_DIR}"
RKBIN_DIR="${STAGING_DIR}/rkbin"
PACK_TOOLS="${EXTERNAL_DIR}/board/luckfox/pico-86panel-w/tools"

# Partition layout — must match the board config
PARTITION_CMD="32K(env),512K@32K(idblock),256K(uboot),32M(boot),512M(oem),256M(userdata),6G(rootfs)"
# CMA must be large enough for the 720x720 LCD framebuffer (~2 MB/buffer).
# coherent_pool=256K overrides any stale DTS coherent_pool=0 (kernel uses
# last value); 256K is the kernel default and sufficient for atomic DMA.
BOOTARGS_CMA="coherent_pool=256K cma=16M"

echo "=== Luckfox 86Panel W post-image ==="
echo "    BINARIES_DIR : ${BINARIES}"
echo "    RKBIN_DIR    : ${RKBIN_DIR}"

# ── Step 1: Pack Rockchip U-Boot loader images ────────────────────────────────
#
# Buildroot only runs `make` for U-Boot, but the Rockchip FIT packing
# (lzma compress → digest → mkimage → uboot.img) and the SPL/loader
# assembly (idblock.img, download.bin) are handled by make.sh / spl.sh
# outside the Makefile.  We call make.sh here to (re)generate everything
# from the already-compiled U-Boot binaries.
#
echo "--- Packing Rockchip U-Boot loader images ---"
# Buildroot names the build dir after the version/tag (e.g. uboot-2017.09-sdk-...)
# so we resolve it with a glob rather than hardcoding the name.
UBOOT_BUILD_DIR="$(echo "${BUILD_DIR}"/uboot-*/ | awk '{print $1}')"
UBOOT_BUILD_DIR="${UBOOT_BUILD_DIR%/}"
INI_FILE="${RKBIN_DIR}/RKBOOT/RV1106MINIALL_EMMC_TB.ini"

# Repack the uboot.img FIT image from the freshly compiled U-Boot binaries.
# Buildroot's standard `make` produces u-boot-nodtb.bin and u-boot.dtb but
# the Rockchip FIT packing (lzma → digest → mkimage → uboot.img) is done
# by make.sh/fit-core.sh outside the Makefile.  We reproduce those steps here.
(
  cd "${UBOOT_BUILD_DIR}"

  # 1. LZMA-compress the U-Boot binary
  lzma -k -f u-boot-nodtb.bin

  # 2. SHA-256 digest (raw 32 bytes, referenced by the ITS)
  sha256sum u-boot-nodtb.bin | xxd -r -p > u-boot-nodtb.bin.digest

  # 3. Copy artifacts into fit/ where the ITS /incbin/ paths expect them
  #    u-boot.dtb may not exist after a dirclean rebuild; fall back to dts/dt.dtb
  UBOOT_DTB="u-boot.dtb"
  [ -f "${UBOOT_DTB}" ] || UBOOT_DTB="dts/dt.dtb"
  cp -f u-boot-nodtb.bin.lzma u-boot-nodtb.bin.digest "${UBOOT_DTB}" fit/
  # ITS references "u-boot.dtb", ensure it has that name in fit/
  [ -f fit/u-boot.dtb ] || cp -f fit/"$(basename "${UBOOT_DTB}")" fit/u-boot.dtb

  # 4. Build the FIT ITB
  OFFS_DATA=0x1000
  if grep -q '^CONFIG_FIT_ENABLE_RSA4096_SUPPORT=y' .config 2>/dev/null; then
    OFFS_DATA=0x1200
  fi
  ./tools/mkimage -f fit/u-boot.its -E -p "${OFFS_DATA}" fit/uboot.itb

  # 4. Assemble uboot.img (padded copies of the ITB)
  ITB_MAX_NUM=$(sed -n '/SPL_FIT_IMAGE_MULTIPLE/s/.*=//p' .config)
  ITB_MAX_KB=$(sed -n '/SPL_FIT_IMAGE_KB/s/.*=//p' .config)
  rm -f uboot.img
  for ((i = 0; i < ${ITB_MAX_NUM:-1}; i++)); do
    cat fit/uboot.itb >> uboot.img
    truncate -s "%${ITB_MAX_KB:-256}K" uboot.img
  done
  echo "uboot.img repacked ($(stat -c%s uboot.img) bytes)"
)

# Pack SPL + DDR blobs into idblock.img / download.bin via scripts/spl.sh
(
  cd "${RKBIN_DIR}"
  "${UBOOT_BUILD_DIR}/scripts/spl.sh" \
    --ini "${INI_FILE}" \
    --spl "${UBOOT_BUILD_DIR}/spl/u-boot-spl.bin"
)

# Extract the output filenames declared in the INI [OUTPUT] section.
DL_BIN="${RKBIN_DIR}/$(sed -n '/^PATH=/s/PATH=//p' "${INI_FILE}" | tr -d '\r')"
IDB_IMG="${RKBIN_DIR}/$(sed -n '/^IDB_PATH=/s/IDB_PATH=//p' "${INI_FILE}" | tr -d '\r')"

cp -v "${DL_BIN}"  "${BINARIES}/download.bin"
cp -v "${IDB_IMG}" "${BINARIES}/idblock.img"
cp -v "${UBOOT_BUILD_DIR}/uboot.img" "${BINARIES}/uboot.img"

# ── Step 2: Build boot.img (kernel FIT image) ─────────────────────────────────
#
# The luckfox kernel produces boot.img via scripts/mkimg, which:
#   1. Calls scripts/resource_tool to pack the DTB (and logos) into resource.img
#   2. Fills in kernel/boot.its (arch, compression) and calls mkimage -E to
#      produce a Rockchip FIT image containing kernel + fdt + resource nodes.
#
# All inputs (zImage, DTB, resource_tool) are already present in the kernel
# build directory from the Buildroot kernel build — no recompilation needed.
#
echo "--- Building boot.img ---"
LINUX_BUILD_DIR="$(echo "${BUILD_DIR}"/linux-*/ | tr ' ' '\n' | grep -v 'host-\|util-' | head -1)"
LINUX_BUILD_DIR="${LINUX_BUILD_DIR%/}"
# The host-uboot-tools mkimage (2025.x) is compiled without a valid dtc path
# (MKIMAGE_DTC=""), so it fails on ITS files containing /incbin/() directives.
# The mkimage built from our own U-Boot source (2017.09) has dtc support and
# produces the correct Rockchip -E external-data FIT format.
UBOOT_MKIMAGE="${UBOOT_BUILD_DIR}/tools/mkimage"
(
  # mkimg uses relative paths (scripts/resource_tool, out/) so it must run
  # from the kernel build directory.
  cd "${LINUX_BUILD_DIR}"

  # mkimg calls scripts/resource_tool which may not be in the kernel tree;
  # ensure the one from rkbin is available.
  if [ ! -x scripts/resource_tool ]; then
    cp "${HOST_DIR}/bin/resource_tool" scripts/resource_tool
    chmod +x scripts/resource_tool
  fi

  srctree="${LINUX_BUILD_DIR}" \
  objtree="${LINUX_BUILD_DIR}" \
  ARCH=arm \
  BOOT_ITS="${LINUX_BUILD_DIR}/boot.its" \
  MKIMAGE="${UBOOT_MKIMAGE}" \
    "${LINUX_BUILD_DIR}/scripts/mkimg" \
      --dtb "rv1106g-luckfox-pico-86panel-w.dtb"
)
cp -v "${LINUX_BUILD_DIR}/boot.img" "${BINARIES}/boot.img"

# ── Step 3: Generate env.img ──────────────────────────────────────────────────
#
# The env partition holds U-Boot's environment, which also encodes the
# eMMC partition layout used by the kernel (blkdevparts=).
#
echo "--- Generating env.img ---"
ENV_STR="blkdevparts=mmcblk0:${PARTITION_CMD}"
ENV_STR+=" earlycon=uart8250,mmio32,0xff4c0000,1500000 console=ttyFIQ0,1500000n8"
ENV_STR+=" rootwait root=/dev/mmcblk0p7 rw ${BOOTARGS_CMA}"

# mkenvimage is part of u-boot-tools (host package)
mkenvimage -s 0x8000 -o "${BINARIES}/env.img" - <<< "${ENV_STR}"

# ── Step 4: Pack update.img ───────────────────────────────────────────────────
#
# Assemble all partition images into a single Rockchip update package.
# afptool reads a package-file list; rkImageMaker wraps it with the chip header.
#
echo "--- Packing update.img ---"

# afptool requires a Rockchip "parameter" file with FIRMWARE_VER, CMDLINE, etc.
# Generate one from our partition layout.
# Partition layout in 512-byte sectors (hex), matching PARTITION_CMD:
#   32K(env), 512K@32K(idblock), 256K(uboot), 32M(boot),
#   512M(oem), 256M(userdata), 6G(rootfs)
PARAM_FILE="${BINARIES}/parameter.txt"
cat > "${PARAM_FILE}" <<'EOFPARAM'
FIRMWARE_VER:1.0
MACHINE_MODEL:RV1106
MACHINE_ID:007
MANUFACTURER:RV1106
MAGIC:0x5041524B
ATAG:0x00200800
MACHINE:1106
CHECK_MASK:0x80
PWR_HLD:0,0,A,0,1
TYPE:GPT
CMDLINE:mtdparts=rk29xxnand:0x00000040@0x00000000(env),0x00000400@0x00000040(idblock),0x00000200@0x00000440(uboot),0x00010000@0x00000640(boot),0x00100000@0x00010640(oem),0x00080000@0x00110640(userdata),-@0x00190640(rootfs)
EOFPARAM

# afptool reads a two-column package-file: <partition-name>\t<filename>
PACKAGE_FILE="${BINARIES}/package-file"
cat > "${PACKAGE_FILE}" <<-EOFPKG
	package-file	package-file
	bootloader	download.bin
	parameter	parameter.txt
	env	env.img
	idblock	idblock.img
	uboot	uboot.img
	boot	boot.img
	rootfs	rootfs.ext4
EOFPKG

"${PACK_TOOLS}/afptool" -pack "${BINARIES}" "${BINARIES}/update_tmp.img"
"${PACK_TOOLS}/rkImageMaker" \
    -RK1106 \
    "${BINARIES}/download.bin" \
    "${BINARIES}/update_tmp.img" \
    "${BINARIES}/update.img" \
    -os_type:androidos

rm -f "${BINARIES}/update_tmp.img" "${BINARIES}/package-file" "${BINARIES}/parameter.txt"

echo "=== Firmware images ready in ${BINARIES} ==="
echo "    download.bin  — upload with: upgrade_tool db download.bin"
echo "    update.img    — flash with:  upgrade_tool uf update.img"
