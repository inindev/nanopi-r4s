# nanopi-r4s
linux for the nanopi r4s

---
### debian buster setup
<br/>

**1. download image:**
```
wget https://github.com/inindev/nanopi-r4s/raw/release/debian/mmc_2g.img.xz
```

<br/>

**2. determine the location of the micro sd card:**

 * before plugging-in device:
```
ls -l /dev/sd*
ls: cannot access '/dev/sd*': No such file or directory
```

 * after plugging-in device:
```
ls -l /dev/sd*
brw-rw---- 1 root disk 8, 0 Feb 14  2019 /dev/sda
```

<br/>

**3. in the case above, substitute 'a' for 'X' in the command below (/dev/sda):**
```
sudo sh -c 'xzcat mmc_2g.img.xz > /dev/sdX && sync'
```

#### when the micro sd has finished imaging, use it to boot the nanopi r4s and finish setup

<br/>

**4. login:**
```
user: debian@192.168.1.xxx
pass: debian
```

<br/>

**5. expand rootfs:**
```
sudo ./expand_partition.sh
Would you like to reboot now? [Y/n] Y
```

<br/>

**6. take updates:**
```
sudo apt update
sudo apt upgrade
```

<br/>

**7. generate new sshd keys:**
<br/><sub><i>note that it is important to generate new sshd public/private key pairs as the ones included in the image are available for anyone to download</i></sub>
```
sudo rm -f /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server
```

<br/>

**8. create account & login as new user:**
```
sudo adduser youruserid
echo 'youruserid ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/youruserid
sudo chmod 440 /etc/sudoers.d/youruserid
```

<br/>

**9. lockout and/or delete debian account:**
```
sudo passwd -l debian
sudo chsh -s /usr/sbin/nologin debian
```

```
sudo deluser debian
sudo rm -rf /home/debian
```

<br/>

**10. change hostname (optional):**
```
sudo nano /etc/hostname
sudo nano /etc/hosts
```
