#!/bin/sh

set -e


bcst_addr() {
    local ip=$1
    local bits=$2
    [ $bits -lt 0 -o $bits -gt 32 ] && exit 1

    # ip as number
    local q0=${ip##*.}
    ip=${ip%.*}
    local q1=${ip##*.}
    ip=${ip%.*}
    local q2=${ip#*.}
    local q3=${ip%.*}
    ip=$((($q3 << 24) | ($q2 << 16) | ($q1 << 8) | ($q0)))

    # broadcast bits
    local bm=$((~(~0 << (32-bits))))
    local ba=$((ip | bm))

    local q0=$((ba & 0xff))
    local q1=$(((ba >> 8) & 0xff))
    local q2=$(((ba >> 16) & 0xff))
    local q3=$(((ba >> 24) & 0xff))
    echo "$q3.$q2.$q1.$q0"
}

iface_entry() {
    local base=$1
    local nic=$2
    local name=$3
    local vlan=$4
    local mask=$5

    local ip="$base.$vlan.1"
    local bcast=$(bcst_addr $ip $mask)

    echo "# vlan $vlan - $name"
    echo "auto $nic.$vlan"
    echo "iface $nic.$vlan inet static"
    echo "    address $ip/$mask"
    echo "    broadcast $bcast"
}

enum_vlan_cfg() {
    local base="$1"
    local nic="$2"
    local vlans="$3"

    # list of name:vlan/mask
    set -- $vlans
    for nvm in $@; do
        local name=${nvm%:*}
        local vm=${nvm#*:}
        local vlan=${vm%/*}
        local mask=${vm#*/}

        entry=$(iface_entry $base $nic $name $vlan $mask)
        echo "$entry\n"
    done
}


#
# exit codes
#   0: success
#   1: bad bitmask bit count
#   2: missing vlan.cfg
#
main() {
    local wan='wan0'
    local lan='lan0'
    local base='192.168'

    local vlan_cfg="$(dirname "$0")/vlan.cfg"
    local vlans="$(cat "$vlan_cfg" | tr '\n' ' ' )"
    [ -z "$vlans" ] && exit 2

    echo '\n\033[0;31m/etc/network/interfaces\033[0m'
    cat <<- EOF
	# interfaces(5) file used by ifup(8) and ifdown(8)
	# Include files from /etc/network/interfaces.d:
	source-directory /etc/network/interfaces.d

	# loopback network interface
	auto lo
	iface lo inet loopback

	# wan network interface
	auto $wan
	iface $wan inet dhcp

	# lan network interface
	auto $lan
	iface $lan inet manual
	EOF
    echo
    enum_vlan_cfg "$base" "$lan" "$vlans"
    echo
}
main

