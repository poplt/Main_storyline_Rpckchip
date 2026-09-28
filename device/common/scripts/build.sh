#!/bin/bash
#
# Minimal RockChip-style SDK entry script.
#
# Usage:
#   ./build.sh init
#   ./build.sh kernel
#   ./build.sh kernel-config
#   ./build.sh u-boot
#   ./build.sh fm
#   ./build.sh fm-uboot
#   ./build.sh fm-boot

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
RK_SDK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RK_SCRIPTS_DIR="$SCRIPT_DIR"
RK_CONFIG="$RK_SDK_DIR/.config"

purple()
{
	printf '\033[35m%s\033[0m\n' "$*"
}

load_config()
{
	# Make sure the SDK configuration exists before running a build command.
	# From then on every script only reads this single .config file.
	if [ ! -f "$RK_CONFIG" ] || [ ! -s "$RK_CONFIG" ]; then
		purple "==> SDK .config not found, running mk-init.sh"
		"$RK_SCRIPTS_DIR/mk-init.sh"
	fi

	if [ -f "$RK_CONFIG" ] && [ -s "$RK_CONFIG" ]; then
		# shellcheck disable=SC1090
		. "$RK_CONFIG"
	fi
}

usage()
{
	cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  init      Select chip/board config and generate .config.
  kernel    Build the kernel and pack it into an extboot partition image.
  kernel-config    Open menuconfig and save changes back to the kernel defconfig.
  u-boot    Build mainline U-Boot and copy images to output/uboot.
  fm        Flash both U-Boot and extboot, then reset.
  fm-uboot  Flash output/uboot/u-boot-rockchip.bin to eMMC LBA 0x40.
  fm-boot   Flash output/extboot.img to eMMC boot partition LBA 0x8000.
            Pass -1 to skip the final reset.
EOF
}

case "${1:-}" in
	init)
		shift
		"$RK_SCRIPTS_DIR/mk-init.sh" --force "$@"
		;;
	kernel)
		load_config
		shift
		"$RK_SCRIPTS_DIR/mk-kernel.sh" "$@"
		;;
	kernel-config)
		load_config
		shift
		"$RK_SCRIPTS_DIR/mk-kernel-config.sh" "$@"
		;;
	u-boot)
		load_config
		shift
		"$RK_SCRIPTS_DIR/mk-uboot.sh" "$@"
		;;
	fm)
		shift
		"$RK_SCRIPTS_DIR/mk-fm.sh" "$@"
		;;
	fm-uboot)
		shift
		"$RK_SCRIPTS_DIR/mk-fm-uboot.sh" "$@"
		;;
	fm-boot)
		shift
		"$RK_SCRIPTS_DIR/mk-fm-boot.sh" "$@"
		;;

	help|-h|--help|"")
		usage
		;;
	*)
		echo "Unknown command: $1" >&2
		usage
		exit 1
		;;
esac
