# nanopi-r4s
linux for the nanopi r4s

---
### debian buster setup
<br/>

**1. download image:**
```
wget https://media.githubusercontent.com/media/inindev/nanopi-r4s/release/debian/buster.img.xz
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

**3. in the case above, substitute 'a' for 'X' in the command below (for /dev/sda):**
```
sudo sh -c 'xzcat buster.img.xz > /dev/sdX && sync'
```

#### when the micro sd has finished imaging, use it to boot the nanopi r4s and finish setup

<br/>

**4. login:**
```
user: debian@192.168.1.xxx
pass: debian
```

<br/>

**5. take updates:**
```
sudo apt update
sudo apt upgrade
```

<br/>

**6. create account & login as new user:**
```
sudo adduser youruserid
echo 'youruserid ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/youruserid
sudo chmod 440 /etc/sudoers.d/youruserid
```

<br/>

**7. lockout and/or delete debian account:**
```
sudo passwd -l debian
sudo chsh -s /usr/sbin/nologin debian
```

```
sudo deluser debian
sudo rm -rf /home/debian
```

<br/>

**8. change hostname (optional):**
```
sudo nano /etc/hostname
sudo nano /etc/hosts
```

