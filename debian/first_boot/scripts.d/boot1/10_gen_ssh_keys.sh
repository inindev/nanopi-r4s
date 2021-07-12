#!/bin/sh

set -e

/usr/bin/rm -f /etc/ssh/ssh_host_*
/usr/sbin/dpkg-reconfigure openssh-server

