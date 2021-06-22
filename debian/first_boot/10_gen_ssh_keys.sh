#!/bin/sh

set -e

if [ "0" != "$(id -u)" ]; then
    echo 'this script must be run as root'
    exit 1
fi

rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

