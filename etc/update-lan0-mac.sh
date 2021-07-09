#!/bin/sh

# set lan0 to the odd eeprom mac address
macstr=$(sudo xxd -s250 -l6 -p /sys/devices/platform/ff120000.i2c/i2c-2/2-0051/eeprom)
mac=$(printf '%012x' $((0x$macstr | 0x01)) | sed 's/../&:/g;s/:$//')
sudo sed -i "s/MACAddress=.*/MACAddress=$mac/" /etc/systemd/network/10-name-lan0.link

