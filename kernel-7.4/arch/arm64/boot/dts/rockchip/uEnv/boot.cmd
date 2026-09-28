echo [boot.cmd] run boot.cmd scripts ...

if test -e ${devtype} ${devnum}:${distro_bootpart} /uEnv/uEnv.txt; then
    echo [boot.cmd] load uEnv.txt ...
    load ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} /uEnv/uEnv.txt
    env import -t ${scriptaddr} 0x8000

    part number ${devtype} ${devnum} "rootfs" rootfs_part
    part uuid ${devtype} ${devnum}:${rootfs_part} rootfs_uuid
    setenv bootargs ${bootargs} root=PARTUUID=${rootfs_uuid} boot_part=${distro_bootpart} ${cmdline}
    printenv bootargs

    if test -e ${devtype} ${devnum}:${distro_bootpart} /initrd-${uname_r}; then
        echo [boot.cmd] load initrd-${uname_r} ...
        load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd-${uname_r}
    else
        echo [boot.cmd] no initrd, boot without ramdisk
        setenv ramdisk_addr_r -
    fi

    echo [boot.cmd] loading /Image-${uname_r} ...
    load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /Image-${uname_r}

    echo [boot.cmd] loading /rk-kernel.dtb
    load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /rk-kernel.dtb

    fdt addr ${fdt_addr_r}
    echo [boot.cmd] booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
fi

echo [boot.cmd] run boot.cmd scripts failed
