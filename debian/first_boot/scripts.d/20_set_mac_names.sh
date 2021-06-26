#!/bin/sh

set -e

if [ ! -f /etc/systemd/network/10-name-lan0.link ]; then
    macstr=$(hexdump -s250 -n6 -ve '6/1 "%02x"' /sys/devices/platform/ff120000.i2c/i2c-2/2-0051/eeprom)
    mac=$(printf "%012x" $((0x$macstr+1)) | sed 's/../&:/g;s/:$//')

    cat <<-EOF > /etc/systemd/network/10-name-lan0.link
	[Match]
	Path=platform-f8000000.pcie-pci-0000:01:00.0
	[Link]
	Name=lan0
	MACAddress=$mac
	EOF

    unset mac
    unset macstr
fi

if [ ! -f /etc/systemd/network/10-name-wan0.link ]; then
    cat <<-EOF > /etc/systemd/network/10-name-wan0.link
	[Match]
	Path=platform-fe300000.ethernet
	[Link]
	Name=wan0
	EOF
fi

