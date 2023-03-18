# nanopi-r4s
stock debian arm64 linux for the nanopi r4s

---
### debian bookworm setup

<br/>

**1. download image**
```
wget https://github.com/inindev/nanopi-r4s/releases/download/v12-rc1/nanopi-r4s_bookworm-rc1.img.xz
```

<br/>

**2. determine the location of the target micro sd card**

 * before plugging-in device
```
ls -l /dev/sd*
ls: cannot access '/dev/sd*': No such file or directory
```

 * after plugging-in device
```
ls -l /dev/sd*
brw-rw---- 1 root disk 8, 0 Mar  7 03:14 /dev/sda
```
* note: for mac, the device is ```/dev/rdiskX```

<br/>

**3. in the case above, substitute 'a' for 'X' in the command below (for /dev/sda)**
```
sudo sh -c 'xzcat bookworm.img.xz > /dev/sdX && sync'
```

#### when the micro sd has finished imaging, eject and use it to boot the nanopi r4s to finish setup

<br/>

**4. login account**
```
user: debian
pass: debian
```

<br/>

**5. take updates**
```
sudo apt update
sudo apt upgrade
```

<br/>

**6. create account & login as new user**
```
sudo adduser youruserid
echo '<youruserid> ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/<youruserid>
sudo chmod 440 /etc/sudoers.d/<youruserid>
```

<br/>

**7. lockout and/or delete debian account**
```
sudo passwd -l debian
sudo chsh -s /usr/sbin/nologin debian
```

```
sudo deluser --remove-home debian
sudo rm /etc/sudoers.d/debian
```

<br/>

**8. change hostname (optional)**
```
sudo nano /etc/hostname
sudo nano /etc/hosts
```

<br/>


---
### booting directly to usb from micro sd bootstrap

<br/>

The nanopi r4s board always needs to bootstrap from a micro sd card as it contains no embedded flash like a raspberry pi4. 
The minimum required binary for the micro sd is a special version of uboot which redirects the boot process to an attached 
usb emmc (nand flash) drive.

<br/>

**1. download images**
```
wget https://github.com/inindev/nanopi-r4s/releases/download/v12-rc1/usb_idbloader.img
wget https://github.com/inindev/nanopi-r4s/releases/download/v12-rc1/usb_u-boot.itb
```

<br/>

**2. determine the location of the target micro sd card**

 * before plugging-in device
```
ls -l /dev/sd*
ls: cannot access '/dev/sd*': No such file or directory
```

 * after plugging-in device
```
ls -l /dev/sd*
brw-rw---- 1 root disk 8, 0 Jul  2 16:33 /dev/sda
```
* note: for mac, the device is ```/dev/rdiskX```

<br/>

**3. in the case above, substitute 'a' for 'X' in the command below (for /dev/sda)**
```
cat /dev/zero | sudo tee /dev/sdX
sudo dd bs=4K seek=8 if=usb_rksd_loader.img of=/dev/sdX conv=notrunc
sudo dd bs=4K seek=2048 if=usb_u-boot.itb of=/dev/sdX conv=notrunc,fsync
```

#### when the micro sd has finished imaging, eject and use it to boot the nanopi r4s to usb

<br/>


---
### building debian bookworm arm64 for the nanopi r4s from scratch

<br/>

The build script builds native arm64 binaries and thus needs to be run from an arm64 device such as a raspberry pi4 running 
a 64 bit arm linux. The initial build of this project used a debian arm64 raspberry pi4, but now uses a nanopi r4s running 
stock debian bookworm arm64.

<br/>

**1. clone the repo**
```
git clone https://github.com/inindev/nanopi-r4s.git
cd nanopi-r4s
```

<br/>

**2. run the debian build script**
```
cd debian
sudo sh make_debian_img.sh
```
* note: edit the build script to change various options: ```nano make_debian_img.sh```

<br/>

**3. the output if the build completes successfully**
```
mmc_2g.img.xz
```

<br/>

