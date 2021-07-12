#!/bin/sh

set -e

/usr/bin/ln -nsf boot2 /root/first_boot/scripts.d/active
/sbin/reboot

