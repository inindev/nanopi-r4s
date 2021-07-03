#!/bin/sh

rm -rf ../../first_boot

[ -n $REBOOT ] && /sbin/reboot

