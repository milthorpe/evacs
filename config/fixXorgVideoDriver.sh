#!/bin/sh

# Adjust xorg configuration for specific video cards.

# Adjustments are made by adding /etc/X11/xorg.conf.d/Device.conf

DEVICE_CONF=/etc/X11/xorg.conf.d/Device.conf

# Don't do anything if there is already such a file.

if [[ -f $DEVICE_CONF ]] ; then
  exit 0
fi

# Handle specific video cards.

# VIA VX875

/sbin/lspci -n | grep -q '1106:5122'

if [[ $? == 0 ]] ; then
cat > $DEVICE_CONF <<EOF
Section "Device"
  Identifier "Card0"
  Option     "VBEModes" "True"
EndSection
EOF
  chmod 644 $DEVICE_CONF
fi


# End VIA VX875
