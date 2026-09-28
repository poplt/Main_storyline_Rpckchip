#!/usr/bin/env bash
#
# mk-fm.sh - flash both U-Boot and extboot to a board in Rockchip Maskrom mode.
#
# Usage:
#   ./build.sh fm        detect device, write U-Boot + extboot, then reset
#   ./build.sh fm -1     detect device and write both images, do not reset

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
RK_SDK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RKDEVTOOL="/usr/local/bin/rkdeveloptool"
RKDEVTOOL_LOADER="${FM_LOADER:-/tmp/rk3588_spl_loader_v1.15.113.bin}"
UBOOT_IMAGE="$RK_SDK_DIR/output/uboot/u-boot-rockchip.bin"
UBOOT_LBA="0x40"
EXTBOOT_IMAGE="$RK_SDK_DIR/output/extboot.img"
EXTBOOT_LBA="0x8000"

die()
{
	echo "error: $*" >&2
	exit 1
}

purple()
{
	printf '\033[35m%s\033[0m\n' "$*"
}

NO_REBOOT=0
for arg in "$@"; do
	case "$arg" in
		-1|--no-reboot)
			NO_REBOOT=1
			;;
		*)
			die "unknown fm argument: $arg"
			;;
	esac
done

[ -x "$RKDEVTOOL" ] || die "rkdeveloptool not found: $RKDEVTOOL"
[ -f "$RKDEVTOOL_LOADER" ] || die "loader not found: $RKDEVTOOL_LOADER"
[ -f "$UBOOT_IMAGE" ] || die "U-Boot image not found: $UBOOT_IMAGE"
[ -f "$EXTBOOT_IMAGE" ] || die "extboot image not found: $EXTBOOT_IMAGE"

purple "==> Flash parameters"
purple "    RKDEVTOOL       = $RKDEVTOOL"
purple "    LOADER          = $RKDEVTOOL_LOADER"
purple "    UBOOT_IMAGE     = $UBOOT_IMAGE"
purple "    UBOOT_LBA       = $UBOOT_LBA"
purple "    EXTBOOT_IMAGE   = $EXTBOOT_IMAGE"
purple "    EXTBOOT_LBA     = $EXTBOOT_LBA"
purple "    RESET_AFTER     = $([ "$NO_REBOOT" -eq 0 ] && echo yes || echo no)"

purple "==> Detecting Maskrom device"
if ! sudo "$RKDEVTOOL" ld; then
	die "no Rockchip device found in Maskrom mode"
fi

purple "==> Downloading USB loader"
sudo "$RKDEVTOOL" db "$RKDEVTOOL_LOADER"

purple "==> Writing U-Boot image"
sudo "$RKDEVTOOL" wl "$UBOOT_LBA" "$UBOOT_IMAGE"

purple "==> Writing extboot image"
sudo "$RKDEVTOOL" wl "$EXTBOOT_LBA" "$EXTBOOT_IMAGE"

if [ "$NO_REBOOT" -eq 0 ]; then
	purple "==> Resetting device"
	sudo "$RKDEVTOOL" rd
else
	purple "==> Skipping reset (-1)"
fi

purple "Flash finished"
