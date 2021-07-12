#!/bin/sh

set -e

/sbin/resize2fs $(/usr/bin/findmnt / -o source -n)

