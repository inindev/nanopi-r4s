#!/bin/sh

set -e

#
# script exit codes:
#   1: missing utility
#   2: download failure
#   3: image mount failure
#

main() {
    # file media is sized with the number between 'mmc_' and '.img'
    #   use 'm' for 1024^2 and 'g' for 1024^3
    local media='mmc_2g.img' # or block device '/dev/sdX'
    local mountpt='rootfs'
    local deb_dist='buster'
    local hostname='deb-arm64'
    local acct_uid='debian'
    local acct_pass='debian'
    local disable_ipv6='true'

    check_installed 'debootstrap' 'u-boot-tools' 'pv' 'wget'

    echo '\ndownloading files...'
    local rtfw=$(download 'cache' 'http://ftp.debian.org/debian/pool/non-free/f/firmware-nonfree/firmware-realtek_20190114-2_all.deb')
    local dtb=$(download 'cache' 'https://github.com/inindev/nanopi-r4s/raw/release/dtb/rk3399-nanopi-r4s.dtb')
    local uboot_rksd=$(download 'cache' 'https://github.com/inindev/nanopi-r4s/raw/release/uboot/rksd_loader.img')
    local uboot_itb=$(download 'cache' 'https://github.com/inindev/nanopi-r4s/raw/release/uboot/u-boot.itb')

    if [ ! -b "$media" ]; then
        echo '\ncreating image file...'
        make_image_file "$media"
    fi

    format_media "$media"

    local del_mountpt=$([ -d "$mountpt" ] && echo 0 || echo 1)
    mount_media "$media" "$mountpt"

    # do not write the cache to the image
    mkdir -p 'cache/var/cache' 'cache/var/lib/apt/lists'
    mkdir -p "$mountpt/var/cache" "$mountpt/var/lib/apt/lists"
    mount -o bind 'cache/var/cache' "$mountpt/var/cache"
    mount -o bind 'cache/var/lib/apt/lists' "$mountpt/var/lib/apt/lists"

    echo '\ninstalling root filesystem...'
    debootstrap --arch arm64 "$deb_dist" "$mountpt" 'https://deb.debian.org/debian/'

    echo '\nconfiguring...'
    echo 'link_in_boot = 1' > "$mountpt/etc/kernel-img.conf"
    echo "$(file_apt_sources $deb_dist)\n" > "$mountpt/etc/apt/sources.list"
    echo "$(file_locale_cfg)\n" > "$mountpt/etc/default/locale"
    echo "\n$(file_network_interfaces)\n" >> "$mountpt/etc/network/interfaces"

    # hostname
    echo $hostname > "$mountpt/etc/hostname"
    sed -i "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost\n127.0.1.1\t$hostname/" "$mountpt/etc/hosts"

    # enable ll alias
    sed -i "s/#alias ll='ls -l'/alias ll='ls -l'/" "$mountpt/etc/skel/.bashrc"
    sed -i "s/# export LS_OPTIONS='--color=auto'/export LS_OPTIONS='--color=auto'/" "$mountpt/root/.bashrc"
    sed -i "s/# eval \"\`dircolors\`\"/eval \"\`dircolors\`\"/" "$mountpt/root/.bashrc"
    sed -i "s/# alias ls='ls \$LS_OPTIONS'/alias ls='ls \$LS_OPTIONS'/" "$mountpt/root/.bashrc"
    sed -i "s/# alias ll='ls \$LS_OPTIONS -l'/alias ll='ls \$LS_OPTIONS -l'/" "$mountpt/root/.bashrc"

    echo '\nconfiguring boot files...'
    echo "$(script_boot_txt $disable_ipv6)\n" > "$mountpt/boot/boot.txt"
    mkimage -A arm -O linux -T script -C none -n 'u-boot boot script' -d "$mountpt/boot/boot.txt" "$mountpt/boot/boot.scr"
    echo "$(script_mkscr_sh)\n" > "$mountpt/boot/mkscr.sh"
    chmod 754 "$mountpt/boot/mkscr.sh"
    install -m 644 "$dtb" "$mountpt/boot"
    ln -s $(basename "$dtb") "$mountpt/boot/dtb"

    echo '\ninstalling realtek firmware...'
    ar p "$rtfw" data.tar.xz | tar -C "$mountpt" -xJvf - ./lib/firmware/rtl_nic

    echo '\nphase 2: chroot setup...'
    local p2s_dir="$mountpt/tmp/phase2_setup"
    mkdir "$p2s_dir"
    cp -r first_boot "$p2s_dir"
    if [ -b "$media" ]; then
        # expansion not needed for block media
        rm -f "$p2s_dir/first_boot/scripts.d/90_expand_rootfs.sh"
    fi
    echo "$(script_phase2_setup_sh $acct_uid $acct_pass)\n" > "$p2s_dir/phase2_setup.sh"

    mount -t proc '/proc' "$mountpt/proc"
    mount -t sysfs '/sys' "$mountpt/sys"
    mount -o bind '/dev' "$mountpt/dev"
    mount -o bind '/dev/pts' "$mountpt/dev/pts"
    chroot "$mountpt" '/bin/sh' '/tmp/phase2_setup/phase2_setup.sh'
    umount "$mountpt/dev/pts"
    umount "$mountpt/dev"
    umount "$mountpt/sys"
    umount "$mountpt/proc"
    umount "$mountpt/var/cache"
    umount "$mountpt/var/lib/apt/lists"

    rm -rf "$p2s_dir"

    if [ ! -b "$media" ]; then
        # reduce entropy in free space to enhance compression
        cat /dev/zero > "$mountpt/tmp/zero.bin" 2> /dev/null || true
        sync
        rm -f "$mountpt/tmp/zero.bin"
    fi

    umount "$mountpt"
    # only cleanup mount point if we made it
    [ "0" != "$del_mountpt" ] && rm -rf "$mountpt"

    echo '\ninstalling u-boot...'
    dd bs=4K seek=8 if="$uboot_rksd" of="$media" conv=notrunc
    dd bs=4K seek=2048 if="$uboot_itb" of="$media" conv=notrunc
    sync

    if [ -b "$media" ]; then
        echo '\nmedia is now ready'
    else
        echo '\ncompressing image file...'
        pv "$media" | xz -z > "$media.xz"
        rm -f "$media"

        echo '\ncompressed image is now ready'
        echo '\ncopy image to media:'
        echo "  sudo sh -c 'xzcat $media.xz > /dev/sdX && sync'"
    fi
    echo
}

make_image_file() {
    local filename=$1
    rm -f "$filename"
    local size="$(echo "$filename" | sed -rn 's/.*mmc_([[:digit:]]+[m|g])\.img$/\1/p' | sed -e 's/g/ << 14/' -e 's/m/ << 4/')"
    dd bs=64K count=$(($size)) if=/dev/zero of="$filename"
}

# partition & create ext4 filesystem
format_media() {
    local media=$1

    # partition with gpt
    cat <<-EOF | sfdisk "$media"
	label: gpt
	unit: sectors
	first-lba: 2048
	part1: start=32768, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
	EOF
    sync

    # create ext4 filesystem
    if [ -b "$media" ]; then
        local part1="/dev/$(lsblk -no kname "$media" | grep '.*1$')"
        mkfs.ext4 "$part1"
    else
        local lodev=$(losetup -f)
        losetup -P "$lodev" "$media"
        sync
        mkfs.ext4 "${lodev}p1"
        sync
        losetup -d "$lodev"
    fi
    sync
}

# mount filesystem
mount_media() {
    local media=$1
    local mountpoint=$2

    if [ -d "$mountpoint" ]; then
        if [ -d "$mountpoint/lost+found" ]; then
            umount "$mountpoint" 2> /dev/null | true
        fi
    else
        mkdir -p "$mountpoint"
    fi

    if [ -b "$media" ]; then
        local part1="/dev/$(lsblk -no kname "$media" | grep '.*1$')"
        mount -n "$part1" "$mountpoint"
    else
        mount -n -o loop,offset=16M "$media" "$mountpoint"
    fi

    if [ ! -d "$mountpoint/lost+found" ]; then
        echo 'failed to mount the image file'
        exit 3
    fi
}

# download / return file from cache
download() {
    local cache=$1
    local url=$2

    if [ ! -d "$cache" ]; then
        mkdir -p "$cache"
    fi

    local filename=$(basename "$url")
    local filepath="$cache/$filename"
    if [ ! -f "$filepath" ]; then
        wget "$url" -P "$cache"
    fi

    if [ ! -f "$filepath" ]; then
        exit 2
    fi

    echo "$filepath"
}

# check if utility program is installed
check_installed() {
    local todo
    for item in "$@"; do
        dpkg -l "$item" 2>\&1>/dev/null || todo="$todo $item"
    done

    if [ ! -z "$todo" ]; then
        echo "this script requires the following packages:\033[0;33m$todo\033[0m\n"
        exit 1
    fi
}

file_apt_sources() {
    local deb_dist=$1

    cat <<-EOF
	# For information about how to configure apt package sources,
	# see the sources.list(5) manual.

	deb http://deb.debian.org/debian/ $deb_dist main
	deb-src http://deb.debian.org/debian/ $deb_dist main

	deb http://security.debian.org/debian-security/ $deb_dist/updates main
	deb-src http://security.debian.org/debian-security/ $deb_dist/updates main

	deb http://deb.debian.org/debian/ $deb_dist-updates main
	deb-src http://deb.debian.org/debian/ $deb_dist-updates main
	EOF
}

file_locale_cfg() {
    cat <<-EOF
	LANG="C.UTF-8"
	LANGUAGE=
	LC_CTYPE="C.UTF-8"
	LC_NUMERIC="C.UTF-8"
	LC_TIME="C.UTF-8"
	LC_COLLATE="C.UTF-8"
	LC_MONETARY="C.UTF-8"
	LC_MESSAGES="C.UTF-8"
	LC_PAPER="C.UTF-8"
	LC_NAME="C.UTF-8"
	LC_ADDRESS="C.UTF-8"
	LC_TELEPHONE="C.UTF-8"
	LC_MEASUREMENT="C.UTF-8"
	LC_IDENTIFICATION="C.UTF-8"
	LC_ALL=
	EOF
}

file_network_interfaces() {
    cat <<-EOF
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
}

script_phase2_setup_sh() {
    local uid=${1-debian}
    local pass=${2-debian}

    cat <<-EOF
	#!/bin/sh

	apt update
	apt -y full-upgrade
	apt -y install linux-image-arm64 linux-headers-arm64
	apt -y install openssh-server sudo wget unzip u-boot-tools

	useradd -m $uid -p \$(echo $pass | openssl passwd -6 -stdin) -s /bin/bash
	echo "$uid ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$uid
	chmod 600 /etc/sudoers.d/$uid

	mv /tmp/phase2_setup/first_boot/first_boot.service /etc/systemd/system
	mv /tmp/phase2_setup/first_boot /root
        sed -i "s/1624888888/$(date +%s)/" /etc/systemd/system/first_boot.service
	systemctl enable first_boot.service

	exit
	EOF
}

script_boot_txt() {
    local no_ipv6="$([ "$1" = "true" ] && echo ' ipv6.disable=1')"

    cat <<-EOF
	# after modifying, run ./mkscr.sh

	part uuid \${devtype} \${devnum}:\${bootpart} uuid
	setenv bootargs console=ttyS2,1500000 root=PARTUUID=\${uuid} rw rootwait$no_ipv6 earlycon=uart8250,mmio32,0xff1a0000

	if load \${devtype} \${devnum}:\${bootpart} \${kernel_addr_r} /boot/vmlinuz; then
	    if load \${devtype} \${devnum}:\${bootpart} \${fdt_addr_r} /boot/dtb; then
	        fdt addr \${fdt_addr_r}
	        fdt resize
	        if load \${devtype} \${devnum}:\${bootpart} \${ramdisk_addr_r} /boot/initrd.img; then
	            booti \${kernel_addr_r} \${ramdisk_addr_r}:\${filesize} \${fdt_addr_r};
	        else
	            booti \${kernel_addr_r} - \${fdt_addr_r};
	        fi;
	    fi;
	fi
	EOF
}

script_mkscr_sh() {
    cat <<-EOF
	#!/bin/sh

	if [ ! -x /usr/bin/mkimage ]; then
	    echo 'mkimage not found, please install uboot-tools:'
	    echo '  sudo apt -y install u-boot-tools'
	    exit 1
	fi

	mkimage -A arm -O linux -T script -C none -n 'u-boot boot script' -d boot.txt boot.scr
	EOF
}


if [ "0" != "$(id -u)" ]; then
    echo 'this script must be run as root'
else
    main
fi

