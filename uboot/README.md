## u-boot 2023.01 for the nanopi r4s

<i>Note: This script is intended to be run from a 64 bit arm device such as an odroid m1 or a raspberry pi4.</i>

<br/>

**1. build u-boot images for the nanopi r4s**
```
sh make_uboot.sh
```

<i>the build will produce the target files idbloader.img, and u-boot.itb</i>

<br/>

**2. copy u-boot to mmc or file image**
```
dd bs=4K seek=8 if=idbloader.img of=/dev/sdX conv=notrunc
dd bs=4K seek=2048 if=u-boot.itb of=/dev/sdX conv=notrunc
sync
```

<br/>

**4. optional: clean target**
```
sh make_uboot.sh clean
```

