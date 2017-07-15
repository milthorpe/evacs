#!/bin/sh

# SIPL 2014-05-29
#
# Respond to addition/removal of hiddev devices.
# When one is connected, a symbolic link /dev/usbbarcode
# is created, which points to the raw USB HID input.
# On removal of the device, the symbolic link is removed.
#
# NB: This is highly specific to the layout of /sys.

hiddevnumber=$1

if [[ "$ACTION" == "add" ]] ; then
  hidrawnumber=$(basename \
    /sys/class/usb/hiddev${hiddevnumber}/device/*:*/hidraw/*)
  ln -s /dev/${hidrawnumber} /dev/usbbarcode
  socat /dev/usbbarcode - | socat -u EXEC:/etc/udev/scripts/filterusbbarcode.pl PTY,link=/dev/ttyUSB0 &
elif [[ "$ACTION" == "remove" ]] ; then
  killall socat
  rm -f /dev/usbbarcode
fi
