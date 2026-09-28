#!/usr/bin/env bash
#
# mk-uboot.sh - build mainline U-Boot and copy the generated Rockchip images
# to output/uboot.
#
# Mainline RK3588 U-Boot uses binman, so the usable artifacts are
# u-boot-rockchip.bin (SD/eMMC) and u-boot-rockchip-spi.bin (SPI NOR).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
RK_SDK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RK_CONFIG="$RK_SDK_DIR/.config"
UBOOT_DIR="$RK_SDK_DIR/u-boot"

die()
{
	echo "error: $*" >&2
	exit 1
}

purple()
{
	printf '\033[35m%s\033[0m\n' "$*"
}

[ -f "$RK_CONFIG" ] && [ -s "$RK_CONFIG" ] || die "SDK config not found: $RK_CONFIG"
# shellcheck disable=SC1090
. "$RK_CONFIG"

ARCH="arm"
CROSS_COMPILE="aarch64-linux-gnu-"
PYTHON3="python3"
if ! "$PYTHON3" -c 'import setuptools' >/dev/null 2>&1; then
	if /usr/bin/python3 -c 'import setuptools' >/dev/null 2>&1; then
		PYTHON3="/usr/bin/python3"
	else
		die "python3 with setuptools is required (try: sudo apt install python3-setuptools)"
	fi
fi

# Binman is invoked through "#!/usr/bin/env python3", so it uses PATH.
# Make sure PATH resolves to the same Python that built pylibfdt.
case "$PYTHON3" in
	*/*)
		export PATH="$(dirname "$PYTHON3"):$PATH"
		;;
esac

UBOOT_CFG="${RK_UBOOT_CFG:-orangepi-5-plus-rk3588_defconfig}"
UBOOT_DEFCONFIG="$UBOOT_DIR/configs/$UBOOT_CFG"
UBOOT_OUTPUT_DIR="$RK_SDK_DIR/output/uboot"
UBOOT_JOBS="$(nproc)"
RKBIN_DIR="$RK_SDK_DIR/rkbin/bin/rk35"

ROCKCHIP_TPL="${ROCKCHIP_TPL:-}"
if [ -z "$ROCKCHIP_TPL" ]; then
	ROCKCHIP_TPL="$(find "$RKBIN_DIR" -maxdepth 1 -type f \
		-name "${RK_CHIP}_ddr_lp4_2112MHz_lp5_2400MHz_v*.bin" \
		! -name '*_eyescan_*' ! -name '*_single_vdd2_*' 2>/dev/null | sort | tail -n 1)"
fi

BL31="${BL31:-}"
if [ -z "$BL31" ]; then
	BL31="$(find "$RKBIN_DIR" -maxdepth 1 -type f \
		-name "${RK_CHIP}_bl31_*.elf" 2>/dev/null | sort | tail -n 1)"
fi

[ -n "$ROCKCHIP_TPL" ] || die "ROCKCHIP_TPL not found under $RKBIN_DIR"
[ -n "$BL31" ] || die "BL31 not found under $RKBIN_DIR"

# defconfig may store SDK-relative paths.
case "$ROCKCHIP_TPL" in
	/*) ;;
	*) ROCKCHIP_TPL="$RK_SDK_DIR/$ROCKCHIP_TPL" ;;
esac
case "$BL31" in
	/*) ;;
	*) BL31="$RK_SDK_DIR/$BL31" ;;
esac

[ -f "$ROCKCHIP_TPL" ] || die "ROCKCHIP_TPL not found: $ROCKCHIP_TPL"
[ -f "$BL31" ] || die "BL31 not found: $BL31"
export ROCKCHIP_TPL BL31

[ -d "$UBOOT_DIR" ] || die "u-boot directory not found: $UBOOT_DIR"
[ -f "$UBOOT_DEFCONFIG" ] || die "u-boot defconfig not found: $UBOOT_DEFCONFIG"

purple "==> U-Boot build parameters"
purple "    UBOOT_DIR       = $UBOOT_DIR"
purple "    ARCH            = $ARCH"
purple "    CROSS_COMPILE   = $CROSS_COMPILE"
purple "    PYTHON3         = $PYTHON3"
purple "    DEFCONFIG       = $UBOOT_CFG"
purple "    DEFCONFIG_FILE  = $UBOOT_DEFCONFIG"
purple "    ROCKCHIP_TPL    = $ROCKCHIP_TPL"
purple "    BL31            = $BL31"
purple "    JOBS            = $UBOOT_JOBS"

purple "==> Applying U-Boot defconfig: $UBOOT_CFG"
make -C "$UBOOT_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" PYTHON3="$PYTHON3" "$UBOOT_CFG"

purple "==> Building U-Boot"
make -C "$UBOOT_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" PYTHON3="$PYTHON3" \
	ROCKCHIP_TPL="$ROCKCHIP_TPL" BL31="$BL31" -j"$UBOOT_JOBS"

purple "==> Copying U-Boot images"
rm -rf "$UBOOT_OUTPUT_DIR"
mkdir -p "$UBOOT_OUTPUT_DIR"

COPIED=0
for image in u-boot-rockchip.bin u-boot-rockchip-spi.bin idbloader.img u-boot.itb; do
	if [ -f "$UBOOT_DIR/$image" ]; then
		cp -a "$UBOOT_DIR/$image" "$UBOOT_OUTPUT_DIR/"
		COPIED=1
	else
		echo "warning: $UBOOT_DIR/$image not found, skipping" >&2
	fi
done

[ "$COPIED" -eq 1 ] || die "no U-Boot output images were generated"

purple "U-Boot build finished: $UBOOT_OUTPUT_DIR"
for image in "$UBOOT_OUTPUT_DIR"/*; do
	[ -f "$image" ] && purple "  $(basename -- "$image")"
done
