#!/bin/sh

set -e

main() {
    local lv='6.2.2'
    local rkpath="linux-$lv/arch/arm64/boot/dts/rockchip"

    if [ ! -f "linux-$lv.tar.xz" ]; then
        wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$lv.tar.xz"
    fi

    if [ 'clean' = "$1" ]; then
        rm -f rk3399*
        rm -rf "linux-$lv"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'device-tree-compiler' 'gcc' 'wget' 'xz-utils'

    if [ ! -d "linux-$lv" ]; then
        tar xJvf "linux-$lv.tar.xz" "linux-$lv/include/dt-bindings" "linux-$lv/include/uapi" "$rkpath"
    fi

    if [ 'links' = "$1" ]; then
        ln -sf "$rkpath/rk3399-nanopi-r4s-enterprise.dts"
        ln -sf "$rkpath/rk3399-nanopi-r4s.dts"
        ln -sf "$rkpath/rk3399-nanopi4.dtsi"
        ln -sf "$rkpath/rk3399.dtsi"
        ln -sf "$rkpath/rk3399-opp.dtsi"
        echo '\nlinks created\n'
        exit 0
    fi

    for dt in "rk3399-nanopi-r4s" "rk3399-nanopi-r4s-enterprise"; do
        nanodts="$rkpath/${dt}.dts"
        if [ ! -f "$nanodts.ori" ]; then
            cp "$nanodts" "$nanodts.ori"
        fi

        # lan & wan leds
        if ! grep -q 'r8169-100:00:link' "$nanodts"; then
            sed -i 's/label = "green:lan";/&\n\t\t\tlinux,default-trigger = "r8169-100:00:link";/' "$nanodts"
        fi
        if ! grep -q 'stmmac-0:01:link' "$nanodts"; then
            sed -i 's/label = "green:wan";/&\n\t\t\tlinux,default-trigger = "stmmac-0:01:link";/' "$nanodts"
        fi

        # build
        gcc -I "linux-$lv/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o ${dt}-top.dts "$nanodts"
        dtc -O dtb -o ${dt}.dtb ${dt}-top.dts
        echo "\n${cya}success: ${dt}.dtb${rst}\n"
    done
}

# check if utility program is installed
check_installed() {
    local todo
    for item in "$@"; do
        dpkg -l "$item" 2>/dev/null | grep -q "ii  $item" || todo="$todo $item"
    done

    if [ ! -z "$todo" ]; then
        echo "this script requires the following packages:${bld}${yel}$todo${rst}"
        echo "   run: ${bld}${grn}sudo apt update && sudo apt -y install$todo${rst}\n"
        exit 1
    fi
}

rst='\033[m'
bld='\033[1m'
red='\033[31m'
grn='\033[32m'
yel='\033[33m'
blu='\033[34m'
mag='\033[35m'
cya='\033[36m'
h1="${blu}==>${rst} ${bld}"

main $@

