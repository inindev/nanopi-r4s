#!/bin/sh

rm -rf /root/first_boot

[ -n $REBOOT ] && /sbin/reboot

