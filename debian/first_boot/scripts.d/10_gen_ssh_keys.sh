#!/bin/sh

rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

