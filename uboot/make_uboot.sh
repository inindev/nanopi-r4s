#!/bin/sh

set -e

if [ 'clean' = "$1" ]; then
    rm -f rksd_loader.img u-boot.itb
    git -C u-boot clean -f
    git -C u-boot checkout master
    git -C u-boot branch -D uboot-2021.04
    git -C u-boot pull --ff-only
    exit 0
fi

if [ ! -d u-boot ]; then
    git clone https://github.com/u-boot/u-boot.git
    git -C u-boot fetch --tags
fi

if ! git -C u-boot branch | grep -q uboot-2021.04; then
    git -C u-boot checkout -b uboot-2021.04 v2021.04
    git -C u-boot cherry-pick b69b9f3f54732c303939eb748aad97cd4cf60168
    git -C u-boot am ../patches/0001-remove-video-support.patch
    git -C u-boot am ../patches/0002-make-mmc1-default.patch
    git -C u-boot am ../patches/0003-ethaddr-eth1addr-from-eeprom.patch
    git -C u-boot am ../patches/0004-pcie_dw_rockchip-compilation-errors.patch
    git -C u-boot am ../patches/0005-enable-usb-host.patch
    git -C u-boot am ../patches/0006-vcc3v3-uses-wrong-vcc5-supply-voltage.patch
    # optional boot from usb
    #git -C u-boot am ../patches/0007-optional-boot-from-usb.patch
elif [ 'uboot-2021.04' != "$(git -C u-boot branch | sed -n -e 's/^\* \(.*\)/\1/p')" ]; then
    git -C u-boot checkout uboot-2021.04
fi

if [ ! -f u-boot/rk3399_bl31.elf ]; then
    wget -cP u-boot https://github.com/atf-builds/atf/releases/download/v2.4/rk3399_bl31.elf
fi

make -C u-boot mrproper
make -C u-boot nanopi-r4s-rk3399_defconfig
make -C u-boot -j$(nproc) BL31=rk3399_bl31.elf

# outputs: rksd_loader.img & u-boot.itb
u-boot/tools/mkimage -n rk3399 -T rksd -d u-boot/tpl/u-boot-tpl.bin rksd_loader.img
cat u-boot/spl/u-boot-spl.bin >> rksd_loader.img
cp u-boot/u-boot.itb .

echo '\nu-boot and spl binaries are now ready'
echo '\ncopy images to media:'
echo '  dd bs=4K seek=8 if=rksd_loader.img of=/dev/sdX conv=notrunc'
echo '  dd bs=4K seek=2048 if=u-boot.itb of=/dev/sdX conv=notrunc'
echo '  sync\n'

