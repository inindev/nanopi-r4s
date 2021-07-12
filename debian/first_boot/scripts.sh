#!/bin/sh

set -e

cd /root/first_boot

if [ -d scripts.d/active ]; then
    for s in scripts.d/active/*.sh; do
        if [ -r $s ]; then
            . $s
        fi
    done
    unset s
fi

