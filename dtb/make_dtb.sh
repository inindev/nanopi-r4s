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

    nanodts="$rkpath/rk3399-nanopi-r4s.dts"
    if [ ! -f "$nanodts.ori" ]; then
        cp "$nanodts" "$nanodts.ori"
    fi

    nanodts_ent="$rkpath/rk3399-nanopi-r4s-enterprise.dts"
    if [ ! -f "$nanodts_ent.ori" ]; then
        cp "$nanodts_ent" "$nanodts_ent.ori"
    fi

    # lan & wan leds
    if ! grep -q 'r8169-100:00:link' "$nanodts"; then
        sed -i 's/label = "green:lan";/&\n\t\t\tlinux,default-trigger = "r8169-100:00:link";/' "$nanodts"
    fi
    if ! grep -q 'stmmac-0:01:link' "$nanodts"; then
        sed -i 's/label = "green:wan";/&\n\t\t\tlinux,default-trigger = "stmmac-0:01:link";/' "$nanodts"
    fi

    if ! grep -q 'r8169-100:00:link' "$nanodts_ent"; then
        sed -i 's/label = "green:lan";/&\n\t\t\tlinux,default-trigger = "r8169-100:00:link";/' "$nanodts_ent"
    fi
    if ! grep -q 'stmmac-0:01:link' "$nanodts_ent"; then
        sed -i 's/label = "green:wan";/&\n\t\t\tlinux,default-trigger = "stmmac-0:01:link";/' "$nanodts_ent"
    fi

    # see https://patchwork.kernel.org/project/linux-rockchip/patch/20210607081727.4723-1-cnsztl@gmail.com
    #if ! grep -q '&i2c2' "$nanodts"; then
    #    sed -i 's/\&i2c4 {/\&i2c2 {\
    #	eeprom@51 {\
    #		compatible = "microchip,24c02", "atmel,24c02";\
    #		reg = <0x51>;\
    #		pagesize = <16>;\
    #		size = <256>;\
    #		read-only;\
    #	};\
    #};\n\n&/' "$nanodts"
    #fi

    # rk3399dtsi="$rkpath/rk3399.dtsi"
    # if [ ! -f "$rk3399dtsi.ori" ]; then
    #     cp "$rk3399dtsi" "$rk3399dtsi.ori"
    # fi

    # back-out change ec3028e7c83ed03f9cd10c0373d955b489ca5ed6 on 10/07/2021
    # this change produces the error: rockchip-pinctrl pinctrl: bank[0-4] is not valid
    #sed -i 's/gpio0: gpio@ff720000 {/gpio0: gpio0@ff720000 {/' "$rk3399dtsi"
    #sed -i 's/gpio1: gpio@ff730000 {/gpio1: gpio1@ff730000 {/' "$rk3399dtsi"
    #sed -i 's/gpio2: gpio@ff780000 {/gpio2: gpio2@ff780000 {/' "$rk3399dtsi"
    #sed -i 's/gpio3: gpio@ff788000 {/gpio3: gpio3@ff788000 {/' "$rk3399dtsi"
    #sed -i 's/gpio4: gpio@ff790000 {/gpio4: gpio4@ff790000 {/' "$rk3399dtsi"

    # build
    gcc -I "linux-$lv/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o rk3399-nanopi-r4s-top.dts "$nanodts"
    dtc -O dtb -o rk3399-nanopi-r4s.dtb rk3399-nanopi-r4s-top.dts
    echo "\n${cya}success: rk3399-nanopi-r4s.dtb${rst}\n"

    gcc -I "linux-$lv/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o rk3399-nanopi-r4s-enterprise-top.dts "$nanodts_ent"
    dtc -O dtb -o rk3399-nanopi-r4s-enterprise.dtb rk3399-nanopi-r4s-enterprise-top.dts
    echo "\n${cya}success: rk3399-nanopi-enterprise-r4s.dtb${rst}\n"
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

