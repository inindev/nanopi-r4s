#!/bin/sh

set -e

#
# script exit codes:
#   1: missing utility
#   2: download failure
#   3: image mount failure
#

main() {
    local size_mb=2048
    local skip_mb=16
    local img_name="mmc_${size_mb}mb.img"
    local mountpt='rootfs'
    local deb_dist='buster'

    check_installed 'wget' 'chroot' 'debootstrap' 'mkimage' 'pv'

    echo '\ndownloading files...'
    local dtb=$(download 'cache' 'https://github.com/inindev/nanopi-r4s/raw/release/dtb/rk3399-nanopi-r4s.dtb')
    local uboot_rksd=$(download 'cache' 'https://github.com/inindev/nanopi-r4s/raw/release/uboot/rksd_loader.img')
    local uboot_itb=$(download 'cache' 'https://github.com/inindev/nanopi-r4s/raw/release/uboot/u-boot.itb')

    echo '\ncreating image file...'
    make_base_img $img_name $skip_mb $size_mb
    mount_img $img_name $skip_mb $mountpt

    # dont write the cache to the image
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
    echo 'deb-arm64' > "$mountpt/etc/hostname"
    sed -i "s/127.0.0.1\tlocalhost/127.0.0.1\tlocalhost\n127.0.1.1\tdeb-arm64/" "$mountpt/etc/hosts"

    # enable ll alias
    sed -i "s/#alias ll='ls -l'/alias ll='ls -l'/" "$mountpt/etc/skel/.bashrc"
    sed -i "s/# export LS_OPTIONS='--color=auto'/export LS_OPTIONS='--color=auto'/" "$mountpt/root/.bashrc"
    sed -i "s/# eval \"\`dircolors\`\"/eval \"\`dircolors\`\"/" "$mountpt/root/.bashrc"
    sed -i "s/# alias ls='ls \$LS_OPTIONS'/alias ls='ls \$LS_OPTIONS'/" "$mountpt/root/.bashrc"
    sed -i "s/# alias ll='ls \$LS_OPTIONS -l'/alias ll='ls \$LS_OPTIONS -l'/" "$mountpt/root/.bashrc"

    # boot files
    echo "$(script_boot_txt)\n" > "$mountpt/boot/boot.txt"
    mkimage -A arm -O linux -T script -C none -n 'u-boot boot script' -d "$mountpt/boot/boot.txt" "$mountpt/boot/boot.scr"
    echo "$(script_mkscr_sh)\n" > "$mountpt/boot/mkscr.sh"
    chmod 754 "$mountpt/boot/mkscr.sh"
    install -m 644 "$dtb" "$mountpt/boot"
    ln -s $(basename "$dtb") "$mountpt/boot/dtb"

    echo '\nphase 2 setup...'
    local p2s_dir="$mountpt/tmp/phase2_setup"
    mkdir "$p2s_dir"
    cp -r first_boot "$p2s_dir"
    echo "$(script_phase2_setup_sh)\n" > "$p2s_dir/phase2_setup.sh"

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

    # reduce entropy in free space to enhance compression
    cat /dev/zero > "$mountpt/tmp/zero.bin" 2> /dev/null || true
    sync
    rm -f "$mountpt/tmp/zero.bin"

    umount "$mountpt"
    rm -rf "$mountpt"

    echo '\ninstalling u-boot...'
    dd if="$uboot_rksd" of="$img_name" seek=64 conv=notrunc
    dd if="$uboot_itb" of="$img_name" seek=16384 conv=notrunc

    echo '\ncompressing image file...'
    pv "$img_name" | xz -z > "$img_name.xz"
    rm -f "$img_name"

    echo '\ncompressed image is now ready'
    echo '\ncopy image to media:'
    echo "  sudo sh -c 'xzcat $img_name.xz > /dev/sdX && sync'"
    echo
}

# create image filesystem
make_base_img() {
    local filename=$1
    local start_mb=$2
    local size_mb=$3

    # create empty image file
    rm -f "$filename"
    dd bs=64K count=$(($size_mb << 4)) if=/dev/zero of="$filename"

    # partition with gpt
    local start_sec=$(($start_mb << 11))
    local size_sec=$(($size_mb << 11))
    cat <<-EOF | sfdisk "$filename"
	label: gpt
	unit: sectors
	first-lba: 2048
	last-lba: $(($size_sec - 34))
	part1: start=$start_sec, size=$(($size_sec - $start_sec - 33)), type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
	EOF

    # create ext4 filesystem (requires super user)
    local lodev=$(losetup -f)
    losetup -P "$lodev" "$filename"
    mkfs.ext4 "${lodev}p1"
    losetup -d "$lodev"
}

# mount image filesystem
mount_img() {
    local filename=$1
    local start_mb=$2
    local mountpoint=$3

    if [ -d "$mountpoint" ]; then
        if [ -d "$mountpoint/lost+found" ]; then
            umount "$mountpoint" 2> /dev/null | true
        fi
        rm -rf "$mountpoint"
    fi

    mkdir "$mountpoint"
    mount -n -o loop,offset=${start_mb}M "$filename" "$mountpoint"
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
    for item in "$@"
        do
        local filepath=$(which "$item")
        if [ ! -x "$filepath" ]; then
            echo "this script requires $item"
            exit 1
        fi
    done
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
    cat <<-EOF
	#!/bin/sh

	apt update
	apt -y full-upgrade
	apt -y install linux-image-arm64 linux-headers-arm64
	apt -y install openssh-server sudo wget unzip u-boot-tools

	useradd -m debian -p \$(echo debian | openssl passwd -6 -stdin) -s /bin/bash
	echo 'debian ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/debian
	chmod 600 /etc/sudoers.d/debian

	mv /tmp/phase2_setup/first_boot/first_boot.service /etc/systemd/system
	mv /tmp/phase2_setup/first_boot /home/debian
	systemctl enable first_boot.service

	exit
	EOF
}

script_boot_txt() {
    cat <<-EOF
	# after modifying, run ./mkscr.sh

	# mac address (use spaces instead of colons)
	setenv macaddr da 19 c8 7a 6d f4

	part uuid \${devtype} \${devnum}:\${bootpart} uuid
	setenv bootargs console=ttyS2,1500000 root=PARTUUID=\${uuid} rw rootwait earlycon=uart8250,mmio32,0xff1a0000

	if load \${devtype} \${devnum}:\${bootpart} \${kernel_addr_r} /boot/vmlinuz; then
	    if load \${devtype} \${devnum}:\${bootpart} \${fdt_addr_r} /boot/dtb; then
	        fdt addr \${fdt_addr_r}
	        fdt resize
	        fdt set /ethernet@fe300000 local-mac-address "[\${macaddr}]"
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

