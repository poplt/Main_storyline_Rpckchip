#!/bin/bash
#
# Minimal kernel + extboot builder.
# Everything is hardcoded for now (no config file parsing).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RK_SDK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

KERNEL_DIR="$RK_SDK_DIR/linux"

# --- Hardcoded values (edit here for now) ---
DTS_NAME="rk3588-orangepi-5-plus"
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"
BOOT_DIR="$RK_SDK_DIR/extboot"
BOOT_IMG="$RK_SDK_DIR/extboot.img"
ROOTFS_STAGING="$RK_SDK_DIR/rootfs"

DTB="$KERNEL_DIR/arch/$ARCH/boot/dts/rockchip/$DTS_NAME.dtb"
IMAGE="$KERNEL_DIR/arch/$ARCH/boot/Image"
UENV_DIR="$KERNEL_DIR/arch/$ARCH/boot/dts/rockchip/uEnv"

kbuild()
{
	make -C "$KERNEL_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$@"
}

build_kernel()
{
	echo "==> Building kernel, dtbs and modules"
	kbuild Image dtbs modules -j"$(nproc)"
}

pack_extboot()
{
	echo "==> Packing extboot partition"

	rm -rf "$BOOT_DIR"
	mkdir -p "$BOOT_DIR/extlinux" "$BOOT_DIR/dtb/rockchip" "$BOOT_DIR/uEnv"

	[ -f "$IMAGE" ] || { echo "error: $IMAGE not found" >&2; exit 1; }
	[ -f "$DTB" ] || { echo "error: $DTB not found" >&2; exit 1; }

	KERNEL_VER="$(cat "$KERNEL_DIR/include/config/kernel.release" 2>/dev/null || true)"
	[ -n "$KERNEL_VER" ] || KERNEL_VER="unknown"

	cp -a "$IMAGE" "$BOOT_DIR/Image-$KERNEL_VER"
	cp -a "$DTB" "$BOOT_DIR/rk-kernel.dtb"
	cp -a "$DTB" "$BOOT_DIR/dtb/rockchip/"

	# uEnv.txt is consumed by boot.scr (uEnv import / overlay handling).
	if [ -f "$UENV_DIR/uEnv.txt" ]; then
		cp -a "$UENV_DIR/uEnv.txt" "$BOOT_DIR/uEnv/"
		sed -i "s/^uname_r=.*/uname_r=${KERNEL_VER}/" "$BOOT_DIR/uEnv/uEnv.txt"
	else
		echo "warning: $UENV_DIR/uEnv.txt not found, skipping" >&2
	fi

	# boot.cmd -> boot.scr (primary boot path, runs before extlinux).
	if [ -f "$UENV_DIR/boot.cmd" ]; then
		cp -a "$UENV_DIR/boot.cmd" "$BOOT_DIR/boot.cmd"
		if command -v mkimage >/dev/null 2>&1; then
			mkimage -T script -C none -d "$BOOT_DIR/boot.cmd" "$BOOT_DIR/boot.scr" >/dev/null
		else
			echo "warning: mkimage not found, boot.scr not generated" >&2
		fi
	else
		echo "warning: $UENV_DIR/boot.cmd not found, skipping boot.scr" >&2
	fi

	cat > "$BOOT_DIR/extlinux/extlinux.conf" <<EOF
label Orange Pi 5 Plus
    kernel /Image-$KERNEL_VER
    fdt /rk-kernel.dtb
    append root=PARTUUID=__CHANGE_ME__ rw rootwait
EOF

	# Install modules into a staging rootfs tree.
	rm -rf "$ROOTFS_STAGING"
	mkdir -p "$ROOTFS_STAGING"
	kbuild INSTALL_MOD_PATH="$ROOTFS_STAGING" modules_install

	# Create the ext2 boot partition image.
	rm -f "$BOOT_IMG"
	truncate -s 128M "$BOOT_IMG"
	mkfs.ext2 -F -L boot -d "$BOOT_DIR" "$BOOT_IMG"

	echo "  Image: $BOOT_IMG is ready"
	echo "  Boot files: $BOOT_DIR"
	echo "  Modules: $ROOTFS_STAGING"
}

build_kernel
pack_extboot
