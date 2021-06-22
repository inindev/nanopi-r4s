#!/bin/sh

cd /home/debian/first_boot

if [ -d scripts.d ]; then
    for s in scripts.d/*.sh; do
        if [ -r $s ]; then
            . $s
        fi
    done
    unset s
fi

