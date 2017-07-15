#! /bin/sh

# This file is (C) copyright 2001-2004 Software Improvements, Pty Ltd
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# Script to copy the Barcode PostScript Files onto a CD
#-------------------------------------------------------
                                                                                                                                                             
# All constants for this file are defined up here.
BARCODES_DIR=/tmp/barcodes   # directory where the barcode postscript files are
ISO_OPTIONS=" -R -T -J "
ISO_FILE=/tmp/evacs_barcodes.iso
                                                                                                                                                             
# console.sh exports:
#          text_mode(MODE FGCOLOUR BGCOLOUR)
#          bailout(msg)
#          warn(msg)
#          announce(msg)
#          instruct(msg)
#          delete_instruction()
source "./console.sh" && CONSOLE='loaded'
                                                                                                                                                             
# cdrom.sh exports:
#           $CDROM_DEVICE
#           $CDROM_DIRECTORY
#           $CDROM_SCSI_DEVICE
#           $CDROM_RECORD_OPTIONS
#           load_blank_cdrom()
#
source "./cdrom.sh" && CDROM='loaded'

# options to mount blank
MOUNT_OPTIONS=""

echo
echo "eVACS v2.0 Barcodes CD Creation"
                                                                                                                                                             

bailout()
{
    echo "$@" >&2
    exit 1
}
                                                                                                                                                             
checkfile()
{
   if [ ! -r $1 ] || [ ! -s $1 ] ; then
        bailout "Required File : $1 is bad. Exiting."
   fi
}
                                                                                                                                                             
createdir()
{
   if [ ! -d $1 ]; then
        mkdir -p $1 || bailout "Could not make $1. Exiting"
        chmod 777 $1
   fi
}
                                                                                                                                                             
checkerror()
{
    if [ -s $EVACS_ERRLOG ] ; then
      bailout "Cannot Proceed: `cat $EVACS_ERRLOG`"
    fi
}


if [ -f $ISO_FILE ]; then
  rm -f $ISO_FILE
fi

createdir $BARCODES_DIR
cd $BARCODES_DIR
if [ `ls | wc -l` -eq 0 ]; then
  bailout "No Barcodes files found. Please generate barcode first!"
fi

announce "Making ISO image for Barcode CD, please wait..."
mkisofs $ISO_OPTIONS -o $ISO_FILE ./
if [ $? != 0 ]; then
 bailout "Barcode CD Generation Failed - Could not generate ISO image!" 
fi
cd -

load_blank_cdrom "Please insert a blank CD-R or CD-RW and press ENTER"
announce "Writing image to CD, please wait..."
# SIPL 2011-08-18 Fedora 14 uses wodim, not cdrecord.
#cdrecord dev=$CDROM_SCSI_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_FILE
wodim dev=$CDROM_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_FILE
if [ $? != 0 ]; then
 bailout "Barcode CD Generation Failed  - Could not Write to CD!"
fi


echo
echo
echo
echo  eVACS Barcode CD successfully created! Thank You!
eject $CDROM_DEVICE
echo
echo
echo
exit 0
                                                                                                                                                             
