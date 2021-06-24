#!/bin/sh

set -e

# prerequisites: build-essential device-tree-compiler
# kernel.org linux version
linux='linux-5.13-rc6'

if [ ! -d "$linux" ]; then
    if [ ! -f "$linux.tar.gz" ]; then
        wget "https://git.kernel.org/torvalds/t/$linux.tar.gz"
    fi
    tar xzvf "$linux.tar.gz" "$linux/include" "$linux/arch/arm64/boot/dts/rockchip"
fi

# patchwork
#wget -O rk3399-nanopi-r4s.patch https://patchwork.kernel.org/project/linux-rockchip/patch/20210610091357.6780-1-cnsztl@gmail.com/raw/
#patch -b -p1 -d "$linux" < rk3399-nanopi-r4s.patch

nanodts="$linux/arch/arm64/boot/dts/rockchip/rk3399-nanopi-r4s.dts"
epgpios='ep-gpios = <\&gpio2 RK_PA4 GPIO_ACTIVE_HIGH>;'
if ! cat "$nanodts" | grep -q "$epgpios"; then
    cp "$nanodts" "$nanodts.ori"
    sed -i "s/^\&pcie0 {/&\n\t$epgpios/" "$nanodts"
fi

# see https://patchwork.kernel.org/project/linux-rockchip/patch/20210607081727.4723-1-cnsztl@gmail.com
if ! cat "$nanodts" | grep -q '&i2c2'; then
sed -i 's/\&i2c4 {/\&i2c2 {\
	eeprom@51 {\
		compatible = "microchip,24c02", "atmel,24c02";\
		reg = <0x51>;\
		pagesize = <16>;\
		size = <256>;\
		read-only;\
	};\
};\n\n&/' "$nanodts"
fi

if [ "$1" = 'links' ]; then
    ln -s "$linux/arch/arm64/boot/dts/rockchip/rk3399-nanopi-r4s.dts"
    ln -s "$linux/arch/arm64/boot/dts/rockchip/rk3399-nanopi4.dtsi"
    ln -s "$linux/arch/arm64/boot/dts/rockchip/rk3399.dtsi"
    ln -s "$linux/arch/arm64/boot/dts/rockchip/rk3399-opp.dtsi"
else
    # build
    gcc -I "$linux/include" -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o rk3399-nanopi-r4s-top.dts "$linux/arch/arm64/boot/dts/rockchip/rk3399-nanopi-r4s.dts"
    dtc -O dtb -o rk3399-nanopi-r4s.dtb rk3399-nanopi-r4s-top.dts
fi

