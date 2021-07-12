#!/bin/sh

set -e

if [ ! -f /etc/systemd/network/10-name-lan0.link ]; then
    macstr=$(/usr/bin/xxd -s250 -l6 -p /sys/devices/platform/ff120000.i2c/i2c-2/2-0051/eeprom)
    mac=$(/usr/bin/printf '%012x' $((0x$macstr | 0x01)) | /usr/bin/sed 's/../&:/g;s/:$//')

    /usr/bin/cat <<-EOF > /etc/systemd/network/10-name-lan0.link
	[Match]
	Path=platform-f8000000.pcie-pci-0000:01:00.0
	[Link]
	Name=lan0
	MACAddress=$mac
	EOF

    unset mac macstr
fi

if [ ! -f /etc/systemd/network/10-name-wan0.link ]; then
    /usr/bin/cat <<-EOF > /etc/systemd/network/10-name-wan0.link
	[Match]
	Path=platform-fe300000.ethernet
	[Link]
	Name=wan0
	EOF
fi

/usr/bin/cat <<-EOF >> /etc/network/interfaces

	# loopback network interface
	auto lo
	iface lo inet loopback

	# lan network interface
	auto lan0
	iface lan0 inet static
	    address 192.168.1.1/24
	    broadcast 192.168.1.255

	# wan network interface
	auto wan0
	iface wan0 inet dhcp

	EOF

