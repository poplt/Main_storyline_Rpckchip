#!/usr/bin/env bash
#
# mk-kernel-config.sh - open menuconfig, then save the result back to the
# kernel defconfig referenced by RK_KERNEL_CFG.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
RK_SDK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RK_CONFIG="$RK_SDK_DIR/.config"
KERNEL_DIR="$RK_SDK_DIR/kernel"

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

ARCH="${RK_ARCH:-arm64}"
CROSS_COMPILE="${RK_CROSS_COMPILE:-aarch64-linux-gnu-}"
KERNEL_CFG="${RK_KERNEL_CFG:-}"
KERNEL_DEFCONFIG=""

[ -n "$KERNEL_CFG" ] || die "RK_KERNEL_CFG is empty"
KERNEL_DEFCONFIG="$KERNEL_DIR/arch/$ARCH/configs/$KERNEL_CFG"
[ -f "$KERNEL_DEFCONFIG" ] || die "kernel defconfig not found: $KERNEL_DEFCONFIG"
[ -d "$KERNEL_DIR" ] || die "kernel directory not found: $KERNEL_DIR"

purple "==> Loading kernel defconfig: $KERNEL_CFG"
make -C "$KERNEL_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$KERNEL_CFG"

purple "==> Opening kernel menuconfig"
make -C "$KERNEL_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" menuconfig

purple "==> Saving defconfig"
make -C "$KERNEL_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" savedefconfig

cp -f "$KERNEL_DIR/defconfig" "$KERNEL_DEFCONFIG"

purple "Kernel config saved to: $KERNEL_DEFCONFIG"
