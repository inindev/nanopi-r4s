#!/bin/sh

set -e


sub_mask() {
    local bits=$1
    [ $bits -lt 0 -o $bits -gt 32 ] && exit 1

    local bm=$((~0 << (32-bits)))
    local q0=$((bm & 0xff))
    local q1=$(((bm >> 8) & 0xff))
    local q2=$(((bm >> 16) & 0xff))
    local q3=$(((bm >> 24) & 0xff))
    echo "$q3.$q2.$q1.$q0"
}

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

dhcp_entry() {
    local base=$1
    local range=$2
    local name=$3
    local vlan=$4
    local mask=$5

    local ip="$base.$vlan.0"
    local router="$base.$vlan.1"
    local bcast=$(bcst_addr $ip $mask)
    local sn_mask=$(sub_mask $mask)
    local ip_min=${ip%.*}.${range%-*}
    local ip_max=${bcast%.*}.${range#*-}

    echo "# vlan $vlan - $name"
    echo "subnet $ip netmask $sn_mask {"
    echo "    range $ip_min $ip_max;"
    echo "    option routers $router;"
    echo "    option subnet-mask $sn_mask;"
    echo "    option broadcast-address $bcast;"
    echo '}'
}

enum_vlan_cfg() {
    local base="$1"
    local range="$2"
    local vlans="$3"

    # list of name:vlan/mask
    set -- $vlans
    for nvm in $@; do
        local name=${nvm%:*}
        local vm=${nvm#*:}
        local vlan=${vm%/*}
        local mask=${vm#*/}

        entry=$(dhcp_entry $base $range $name $vlan $mask)
        echo "$entry\n"
    done
}

dhcp_interface_cfg() {
    local nic="$1"
    local vlans="$2"

    local res
    set -- $vlans
    for nvm in $@; do
        local vm=${nvm#*:}
        local vlan=${vm%/*}
        [ -n "$res" ] && res="$res "
        res="$res$nic.$vlan"
    done

    echo "INTERFACESv4=\"$res\""
}


#
# exit codes
#   0: success
#   1: bad bitmask bit count
#   2: missing vlan.cfg
#
main() {
    local nic='lan0'
    local base='192.168'
    local range='16-254'

    local vlan_cfg="$(dirname "$0")/vlan.cfg"
    local vlans="$(cat "$vlan_cfg" | tr '\n' ' ' )"
    [ -z "$vlans" ] && exit 2

    echo '\n\033[0;31m/etc/dhcp/dhcpd.conf\033[0m'
    cat <<- EOF
	#
	# dhcpd.conf - isc dhcpd configuration file
	#

	authoritative;
	ddns-update-style none;
	default-lease-time $((7 * 24 * 60 * 60));  #  7 days
	max-lease-time $((10 * 24 * 60 * 60));      # 10 days
	option domain-name-servers 1.0.0.1, 1.1.1.1;
	#option domain-name-servers 8.8.4.4, 8.8.8.8;
	option ntp-servers time.apple.com;
	EOF
    echo '\n'
    enum_vlan_cfg "$base" "$range" "$vlans"

    echo '\n\033[0;31m/etc/default/isc-dhcp-server\033[0m'
    dhcp_interface_cfg "$nic" "$vlans"
    echo '\n'


}
main
