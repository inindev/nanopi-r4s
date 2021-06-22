#!/bin/sh

set -e

if [ ! -f /etc/systemd/network/10-name-lan0.link ]; then
    mac=$(hexdump -s250 -n6 -ve '5/1 "%02x:" 1/1 "%02x"' /sys/devices/platform/ff120000.i2c/i2c-2/2-0051/eeprom)

    cat <<-EOF > /etc/systemd/network/10-name-lan0.link
	[Match]
	Path=platform-f8000000.pcie-pci-0000:01:00.0
	[Link]
	Name=lan0
	MACAddress=$mac
	EOF

    unset mac
fi

if [ ! -f /etc/systemd/network/10-name-wan0.link ]; then
    macstr=$(hexdump -s250 -n6 -ve '6/1 "%02x"' /sys/devices/platform/ff120000.i2c/i2c-2/2-0051/eeprom)
    mac=$(printf "%012x" $((0x$macstr+1)) | sed 's/../&:/g;s/:$//')

    cat <<-EOF > /etc/systemd/network/10-name-wan0.link
	[Match]
	Path=platform-fe300000.ethernet
	[Link]
	Name=wan0
	MACAddress=$mac
	EOF

    unset macstr
    unset mac
fi

if [ $(cat /boot/boot.txt | grep -q 'setenv macaddr da 19 c8 7a 6d f4' ; echo $?) ]; then
    macstr=$(hexdump -s250 -n6 -ve '6/1 "%02x"' /sys/devices/platform/ff120000.i2c/i2c-2/2-0051/eeprom)
    mac=$(printf "%012x" $((0x$macstr+1)) | sed 's/../& /g;s/ $//')

    sed -i "s/setenv macaddr da 19 c8 7a 6d f4/setenv macaddr $mac/" /boot/boot.txt
    mkimage -A arm -O linux -T script -C none -n 'u-boot boot script' -d /boot/boot.txt /boot/boot.scr

    unset macstr
    unset mac
fi

