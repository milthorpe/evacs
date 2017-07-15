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

# Script to restore the EVACSv2.0 database
#-----------------------------------------------
# This script can be used to restore the eVACS v2.0 datbase from a backup
# created earlier by the backup_DB script.
#


# All constants for this file are defined up here.
BACKUP_DIR=/tmp/backup    # This needs to be changed to CD-ROM drive
BACKUP_FILE=evacs.pgdump    
BARCODES_DIR=/tmp/barcodes   

# exports text_mode MODE FGCOLOUR BGCOLOUR
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

MOUNT_OPTIONS=" -tiso9660 " 

echo
echo "eVACS v2.0 Database and Barcodes Restore"


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

#extract the archive from the CD
load_evacs_cdrom "Please insert an eVACS Data Backup CD and press ENTER"
RETRY=0
while [[ ! -f $CDROM_DIRECTORY/$BACKUP_FILE && $RETRY != 2 ]] ; do
	 let RETRY=$RETRY+1
    warn "Loaded CD does not contain an eVACS Archive"
    umount $CDROM_DEVICE 2>&1 > /dev/null
    eject $CDROM_DEVICE
    instruct "Please insert an eVACS Data Backup CD and press ENTER."
    read -s
    delete_instruction
    announce "CD Loading                                                                     "
    load_evacs_cdrom "Please insert an eVACS Data Backup CD and press ENTER."
done
if [ $RETRY == 2 ] ; then
	 bailout "Loaded CD does not contain an eVACS archive. Restore failed."
fi

createdir $BARCODES_DIR
createdir $BACKUP_DIR
announce "Copying the Archive to the Hard Disk, please wait..."
rm -rf $BARCODES_DIR/* $BACKUP_DIR/*
cp -R $CDROM_DIRECTORY/*  $BARCODES_DIR
chmod 777 $BARCODES_DIR/*
mv $BARCODES_DIR/$BACKUP_FILE $BACKUP_DIR


# if evacs database exists, give the user one last chance to back out.
y=`su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
select datname from pg_database where datname='evacs';
EOF" `
if [ -s $EVACS_ERRLOG ] ; then
  bailout Cannot access database, please login as root and retry
fi
if [ `echo $y | grep "1 row" | wc -l` -eq 1 ] ; then  #database exists
  echo
  echo
  echo Restoring database from the archive! Any data in the evacs database will be lost and replaced by the data from the archive.
  echo Existing Barcodes will be destroyed and replaced by those on the backup CD.
  echo Press Y to continue, any other key to abort
  read answer
  echo
  if [[ "$answer" == "Y" || "$answer" == "y" ]] ; then
     su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
     drop database evacs;
EOF"
     if [ -s $EVACS_ERRLOG ] ; then
         bailout Could not Drop Database
     fi
  else
      bailout Database Restore aborted on user request
  fi
fi

# now we're ready to create a new database and restore the data from the backup
echo Restoring eVACS database, please wait...  
su postgres -c "psql template1 2>$EVACS_ERRLOG <<EOF
create database evacs
EOF"
checkerror

#check if the group 'evacs_group' exists
y=`su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
select groname from pg_group where groname='evacs_group';
EOF" `
if [ `echo $y | grep "0 rows" | wc -l` -eq 1 ] ; then  #group doesn't exists
    echo CREATE GROUP evacs_group \; | su - postgres -c "psql template1 2>$EVACS_ERRLOG"
fi

announce "Importing Database, please wait..."
su postgres -c "psql evacs < $BACKUP_DIR/$BACKUP_FILE 2> $EVACS_ERRLOG"
if [ `cat $EVACS_ERRLOG | grep -v NOTICE | grep -v "already exists" | wc -l` -gt 0 ]; then
  bailout Error restoring database
fi

echo
echo
echo
rm -f $EVACS_ERRLOG
echo  eVACS Database and Barcode Postscript Files successfully restored. Thank You!
eject $CDROM_DEVICE
echo
echo
echo
exit 0
