#!/bin/sh

/usr/bin/systemctl disable first_boot_cfg.service
/usr/bin/systemctl daemon-reload
/usr/bin/rm -rf /etc/systemd/system/first_boot_cfg.service

cd /root
/usr/bin/rm -rf /root/first_boot

