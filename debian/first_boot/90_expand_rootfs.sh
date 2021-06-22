#!/bin/sh

set -e

install_resize2fs_service() {
    local spath=$1
    local rp=$2
    cat <<-EOF > $spath
	[Unit]
	Description=resize the root filesystem to fill partition
	DefaultDependencies=no
	Conflicts=shutdown.target
	After=local-fs-pre.target
	Before=local-fs.target sysinit.target shutdown.target
	[Service]
	Type=oneshot
	RemainAfterExit=yes
	ExecStart=resize2fs $rp
	ExecStart=systemctl disable resize2fs.service
	ExecStart=rm -f $spath
	StandardOutput=journal
	StandardError=journal
	[Install]
	WantedBy=sysinit.target
	EOF
}

main() {
    if [ "0" != "$(id -u)" ]; then
        echo 'this script must be run as root'
        exit 1
    fi

    local spath='/etc/systemd/system/resize2fs.service'
    local rp=$(findmnt / -o source -n)
    local rpn=$(echo "$rp" | grep -o '[[:digit:]]*$')
    local rd="/dev/$(lsblk -no pkname $rp)"

    install_resize2fs_service $spath $rp
    systemctl enable resize2fs.service

    echo ', +' | sudo sfdisk -f -N $rpn $rd

    reboot
}
main

