#!/bin/sh

set -e

install_resize2fs_service() {
    local spath=$1
    local rp=$2
    local dt=$3
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
	ExecStart=/bin/date --set=@$dt
	ExecStart=/sbin/resize2fs $rp
	ExecStart=/bin/systemctl disable resize2fs.service
	ExecStart=/bin/rm -f $spath
	StandardOutput=journal
	StandardError=journal

	[Install]
	WantedBy=sysinit.target
	EOF
}

main() {
    local spath='/etc/systemd/system/resize2fs.service'
    local rp=$(findmnt / -o source -n)
    local rpn=$(echo "$rp" | grep -o '[[:digit:]]*$')
    local rd="/dev/$(lsblk -no pkname $rp)"
    local dt=$(date +%s)

    install_resize2fs_service $spath $rp $dt
    systemctl enable resize2fs.service

    echo ', +' | /sbin/sfdisk -f -N $rpn $rd

    REBOOT=true
}
main

