## stock debian bookworm linux for the nanopi r4s

<i>Note: This script is intended to be run from a 64 bit arm device such as an odroid m1 or a raspberry pi4.</i>

<br/>

**build debian bookworm using debootstrap**
```
sudo sh make_debian_img.sh
```

<i>the build will produce the target file mmc_2g.img.xz</i>

<br/>

**copy the image to mmc media**
```
sudo sh -c 'xzcat mmc_2g.img.xz > /dev/sdX && sync'
```

<br/>

**multiple build options are available by editing make_debian_img.sh**
```
media='mmc_2g.img' # or block device '/dev/sdX'
deb_dist='bookworm'
hostname='deb-arm64'
acct_uid='debian'
acct_pass='debian'
enterprise_dtb='true'
disable_ipv6='true'
extra_pkgs='pciutils, sudo, wget, u-boot-tools, xxd, xz-utils, zip, unzip'
```

