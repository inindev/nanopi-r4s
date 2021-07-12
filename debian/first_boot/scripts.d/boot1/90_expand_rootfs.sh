#!/bin/sh

set -e

rp=$(/usr/bin/findmnt / -o source -n)
rpn=$(/usr/bin/echo "$rp" | /usr/bin/grep -o '[[:digit:]]*$')
rd="/dev/$(/usr/bin/lsblk -no pkname $rp)"
/usr/bin/echo ', +' | /sbin/sfdisk -f -N $rpn $rd
unset rp rpn rd

