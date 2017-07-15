#! /bin/sh

# This file is (C) copyright 2001-2004 Software Improvements, Pty Ltd */

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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

# Script to backup the EVACSv2.0 database
#-----------------------------------------------
# This script can be used any time the database needs to be backed up.
# Strongly recommended to be used immediately after generating the barcodes.
# In case the barcodes are lost from the database, the only way to restore them
# is from the backup.
#


# All constants for this file are defined up here.
BACKUP_DIR=/tmp/backup       # directory for the evacs pgdump
BACKUP_FILE=evacs.pgdump    
BARCODES_DIR=/tmp/barcodes   # directory where the barcode postscript files are
ISO_OPTIONS=" -R -T -J "
ISO_FILE=/tmp/evacs_backup.iso


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
echo "eVACS v2.0 Database and Barcodes Backup"


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

#
# Script starts here
#
if [ ! -f $EVACS_ERRLOG ] ; then
	 touch $EVACS_ERRLOG
fi
chmod 666 $EVACS_ERRLOG

rm -rf $BACKUP_DIR
createdir $BACKUP_DIR
if [ -f $BACKUP_DIR/$BACKUP_FILE ] ; then
	 rm -f $BACKUP_DIR/$BACKUP_FILE
fi 


echo Backing up eVACS database, please wait...  
su postgres -c "pg_dump evacs -f $BACKUP_DIR/$BACKUP_FILE 2> $EVACS_ERRLOG"
checkerror
chmod 777 $BACKUP_DIR/$BACKUP_FILE

echo Backing up Barcode PostScript files, please wait...  
createdir $BARCODES_DIR
cd $BARCODES_DIR
for x in `ls`
do
  echo Backing up Barcodes for $x...
  rm -rf $BACKUP_DIR/$x
  cp -R $x $BACKUP_DIR
done
# "cd -" prints the new directory. We don't need to see it, so redirect it.
cd - > /dev/null

announce "Making ISO image for CD Backup, please wait..."
cd $BACKUP_DIR
mkisofs $ISO_OPTIONS -o $ISO_FILE ./
if [ $? != 0 ]; then
	 bailout "Backup Failed - Could not generate ISO image!" 
fi
# "cd -" prints the new directory. We don't need to see it, so redirect it.
cd - > /dev/null

load_blank_cdrom "Please insert a blank CD-R or CD-RW for the backup"
announce "Writing image to CD, please wait..."
# SIPL 2011-08-09 Fedora 14 uses wodim, not cdrecord.
#cdrecord dev=$CDROM_SCSI_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_FILE
wodim dev=$CDROM_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_FILE
if [ $? != 0 ]; then
	 bailout "Backup Failed  - Could not Write to CD!"
fi


echo
echo
echo
rm -f $EVACS_ERRLOG
echo  eVACS Database and Barcode Postscript files successfully backed up! Thank You!
eject $CDROM_DEVICE
echo
echo
echo
exit 0
