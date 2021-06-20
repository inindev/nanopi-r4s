#!/bin/sh

set -e


main() {
    if [ ! -d u-boot ]; then
        git clone https://github.com/u-boot/u-boot.git
        git -C u-boot fetch --tags
        git -C u-boot checkout -b uboot-2021.04 v2021.04
        git -C u-boot cherry-pick b69b9f3f54732c303939eb748aad97cd4cf60168
    fi

    if [ ! -f u-boot/rk3399_bl31.elf ]; then
        wget -c https://github.com/atf-builds/atf/releases/download/v2.4/atf-v2.4.tar.gz -O - | tar -C u-boot -xz ./rk3399_bl31.elf
    fi

    git -C u-boot checkout uboot-2021.04

    make -C u-boot mrproper
    make -C u-boot nanopi-r4s-rk3399_defconfig
    make -C u-boot -j$(nproc) BL31=rk3399_bl31.elf

    # outputs: rksd_loader.img & u-boot.itb
    u-boot/tools/mkimage -n rk3399 -T rksd -d u-boot/tpl/u-boot-tpl.bin rksd_loader.img
    cat u-boot/spl/u-boot-spl.bin >> rksd_loader.img
    cp u-boot/u-boot.itb .
}


main

