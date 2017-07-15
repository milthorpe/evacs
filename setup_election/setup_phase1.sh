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

# Script for Phase-1 of the Election Data Setup.
#-----------------------------------------------
# Phase-1 requires the following directory structure:
#
#  master/
#       |-- rotations-5.txt
#       |-- rotations-7.txt
#       |-- rotations-9.txt (optional)
#       |-- master-data.txt
#       |-- electorates.txt
#       |-- pollingplaces.txt
#       |-- batches.txt
#       |-- barcodes.txt
#
                                                                                                                                                             
# All constants for this file are defined up here.
SETUP_DIR=/tmp/setup    # Scratch directory
LOG_FILE=$SETUP_DIR/Phase-1.$$.log  #  Log File for Setup Phase-1
MOUNT_OPTIONS=" -tiso9660 -o uid=`id -u postgres`"

# SIPL 2011-09-15 Define the label to append to polling place names
#  for pre-polling.
PREPOLL="(Pre-Poll)"

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

# A note about processing input data:
# Be careful to strip out carriage returns _before_
# using 'grep -v "^$"'.
# In general you should find every occurrence of 'grep -v "^$"'
# preceded at some point by "sed 's/\r//g'"

source "./cdrom.sh" && CDROM='loaded'                                                                                                                                                             

echo "eVACS v2.0 Elections Data Setup Phase-1"
                                                                                                                                                             

log()
{
    echo "`date`: $@" >> $LOG_FILE
}
                                                                                                                                                             
                                                                                                                                                             
bailout()
{
    log "$@"
    echo "$@" >&2
#    echo "Please see log file $LOG_FILE for details"
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
      bailout "Error while populating the database. Most Probable Cause: Data in setup files. Please amend and re-run Phase-1"
    fi
}

# SIPL 2014-05-19
# Utility function to replace non-alphanumeric characters with underscores.
# This is applied to electorate names. E.g., this will convert
#  "A name with spaces and a hy-phen and an A'postrophe"
# into:
#  "A_name_with_spaces_and_a_hy_phen_and_an_A_postrophe"
normalize_name()
{
    echo -n "$@" | tr -c '[A-Za-z0-9]' _
}

# Create the Scratch Directory and Log File
createdir $SETUP_DIR
log eVacs Election Data Setup Phase-1 initiated!
                                                                                                                                                             
if [ -z $EVACS_HOME ] ; then
  bailout Please set environment variable EVACS_HOME before proceeding with setup!
fi

load_evacs_cdrom "Please insert Phase-1 Data Setup CD and press ENTER."
RETRY=0
while [ ! -d $CDROM_DIRECTORY/master ]; do
	 let RETRY=$RETRY+1
    warn "Loaded CD does not contain a \"master\" directory"
    umount $CDROM_DEVICE 2>&1 > /dev/null
    eject $CDROM_DEVICE
    if [ $RETRY == 3 ] ; then
        bailout "Loaded CD does not contain a \"master\" directory. Loading failed."
    fi
    instruct "Please insert Phase-1 Data Setup CD and press ENTER."
    read -s
    delete_instruction
    announce "CD Loading                                                                     "
    load_evacs_cdrom "Please insert Phase-1 Data Setup CD and  press ENTER."
done

rm -rf $SETUP_DIR/master
cp -R $CDROM_DIRECTORY/master $SETUP_DIR
if [ $? != 0 ]; then
  umount $CDROM_DIRECTORY
  bailout  "Could not read from the CD, perhaps it is corrupt"
fi
chmod -R 777 $SETUP_DIR/master

umount $CDROM_DIRECTORY

# Sanity check
log Validating Election Setup Data....
checkfile $SETUP_DIR/master/rotations-5.txt
checkfile $SETUP_DIR/master/rotations-7.txt
checkfile $SETUP_DIR/master/master-data.txt
checkfile $SETUP_DIR/master/electorates.txt
checkfile $SETUP_DIR/master/pollingplaces.txt
checkfile $SETUP_DIR/master/batches.txt
checkfile $SETUP_DIR/master/barcodes.txt

# 2014-02-07 Loop over electorates.txt, checking for existence
#   of rotations-x.txt, where x is the number of seats.
#   (This could replace the above hard-coded checks for rotations-5.txt
#   and rotations-7.txt ... if all the remaining code that assumes
#   their existence outright is also modified.)
for SEATCOUNT in `cat $SETUP_DIR/master/electorates.txt | sed 's/, /,/g' | sed 's/\r//g' | grep -v "^$" | sed 's/	//g' | awk -F\, ' { print $3 } '`
do
  checkfile $SETUP_DIR/master/rotations-$SEATCOUNT.txt
done


#Drop old Database and create a blank one
log Creating eVACS database...  
rm -f $EVACS_ERRLOG $EVACS_SCRATCH
touch $EVACS_ERRLOG
chmod o+rw $EVACS_ERRLOG

#DEBUG
echo "******"
y=`su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
select datname from pg_database where datname='evacs';
EOF" ` 
#DEBUG
echo "------"
if [ -s $EVACS_ERRLOG ] ; then
  bailout Cannot access database! Is postmaster running?
fi

if [ `echo $y | grep "1 row" | wc -l` -eq 1 ] ; then  #database exists
  # check if the database has the master_data table.
  z=`su postgres -c "psql evacs 2>/dev/null << EOF
     select * from pg_tables where tablename='master_data';
EOF" `  

  if [ `echo $z | grep "0 rows" | wc -l` -eq 1 ] ; then   #Its an eVACS v 1.x database
    echo dropping database evacs
    su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
    drop database evacs;
EOF" 
    if [ -s $EVACS_ERRLOG ] ; then
      bailout Could not Drop Database
    fi
  else                 # eVACS 2.0 database, check if user really wants to drop!
    echo
    echo
    echo Phase-1 of the Election Server Setup was run earlier. If you proceed, the existing data will be lost
    echo Press Y to delete old database and reload the Phase-1 setup again. YOU WILL LOSE ANY BARCODES THAT MAY HAVE BEEN GENERATED.
    echo Press any other key to abort Phase-1 now.
    read answer
    echo
    if [[ "$answer" == "Y" || "$answer" == "y" ]] ; then
      rm -f ./evacs_old.pgdump
      su postgres -c "pg_dump evacs" > ./evacs_old.pgdump
      chmod 777 ./evacs_old.pgdump
      log Old database backed up to `pwd`/evacs_old.pgdump
      su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
      drop database evacs;
EOF" 
      if [ -s $EVACS_ERRLOG ] ; then
        bailout Could not Drop Database
      fi
    else
      bailout Phase-1 aborted on user request 
    fi
  fi
else
 echo creating database
fi


# now we're ready to create the blank database
su postgres -c "psql template1 2>$EVACS_ERRLOG <<EOF
create database evacs
EOF" 
if [ -s $EVACS_ERRLOG ] ; then
  bailout Could not Create Database
fi

su postgres -c "psql -q evacs < ./evacs_blank.pgdump"

# SIPL 2014-05-19 Support electorate names with non-alphanumeric characters
OLDIFS=$IFS
IFS=$'\n'
for ELECTORATE in `cat $SETUP_DIR/master/electorates.txt` ; do
    NAME=$(normalize_name `echo $ELECTORATE | cut -f2 -d,`)
    su postgres -c "psql -q evacs 2>$EVACS_ERRLOG <<EOF
CREATE SEQUENCE ${NAME}_confirmed_id_seq
    START 1
    INCREMENT 1
    MAXVALUE 999999999
    MINVALUE 1
    CACHE 1;

CREATE TABLE ${NAME}_confirmed_vote (
    id integer DEFAULT nextval('${NAME}_confirmed_id_seq'::text) NOT NULL,
    batch_number integer NOT NULL,
    paper_version integer DEFAULT -1 NOT NULL,
    time_stamp text,
    preference_list text
);

CREATE SEQUENCE ${NAME}_paper_id_seq
    START 1
    INCREMENT 1
    MAXVALUE 999999999
    MINVALUE 1
    CACHE 1;

CREATE TABLE ${NAME}_paper (
    id integer DEFAULT nextval('"${NAME}_paper_id_seq"'::text) NOT NULL,
    batch_number integer NOT NULL,
    "index" integer NOT NULL,
    entry_id1 integer DEFAULT -1,
    entry_id2 integer DEFAULT -1,
    supervisor_tick boolean DEFAULT false NOT NULL
);

CREATE SEQUENCE ${NAME}_entry_id_seq
    START 1
    INCREMENT 1
    MAXVALUE 999999999
    MINVALUE 1
    CACHE 1;

CREATE TABLE ${NAME}_entry (
    id integer DEFAULT nextval('"${NAME}_entry_id_seq"'::text) NOT NULL,
    paper_id integer NOT NULL,
    "index" integer NOT NULL,
    operator_id text NOT NULL,
    num_preferences integer NOT NULL,
    paper_version integer NOT NULL,
    preference_list text DEFAULT ''
);

CREATE INDEX ${NAME}_cnfrmd_vt_btch_idx ON ${NAME}_confirmed_vote USING btree (batch_number);

CREATE INDEX ${NAME}_paper_batch_idx ON ${NAME}_paper USING btree (batch_number);

CREATE INDEX ${NAME}_paper_batchnum_idx ON ${NAME}_paper USING btree (batch_number, "index");

CREATE INDEX ${NAME}_entry_paperid_idx ON ${NAME}_entry USING btree (paper_id);

ALTER TABLE ONLY ${NAME}_confirmed_vote
    ADD CONSTRAINT ${NAME}_confirmed_vote_pkey PRIMARY KEY (id);

ALTER TABLE ONLY ${NAME}_paper
    ADD CONSTRAINT ${NAME}_paper_pkey PRIMARY KEY (id);

ALTER TABLE ONLY ${NAME}_entry
    ADD CONSTRAINT ${NAME}_entry_pkey PRIMARY KEY (id);

GRANT ALL ON ${NAME}_confirmed_id_seq TO GROUP evacs_group;
GRANT ALL ON ${NAME}_confirmed_vote TO GROUP evacs_group;
GRANT ALL ON ${NAME}_entry TO GROUP evacs_group;
GRANT ALL ON ${NAME}_entry_id_seq TO GROUP evacs_group;
GRANT ALL ON ${NAME}_paper TO GROUP evacs_group;
GRANT ALL ON ${NAME}_paper_id_seq TO GROUP evacs_group;
EOF" 
done
IFS=$OLDIFS

echo Database created!
log Blank eVACS v2.0 database created.


#Copy the files and strip off the unnecessary spaces as well.
log Copying Files...  
createdir $EVACS_HOME/var/www/html/data
cp $SETUP_DIR/master/master-data.txt  $EVACS_HOME/var/www/html/data/master-data.txt
cat $SETUP_DIR/master/rotations-5.txt | sed 's/, /,/g' | awk -F\, '{ print $1-1","$2-1","$3-1","$4-1","$5-1 }' >	$EVACS_HOME/var/www/html/data/Rotations-5
cat $SETUP_DIR/master/rotations-7.txt | sed 's/, /,/g' | awk -F\, '{ print $1-1","$2-1","$3-1","$4-1","$5-1","$6-1","$7-1 }' >	$EVACS_HOME/var/www/html/data/Rotations-7
# 2014-02-07 Support rotations-9.txt, if present.
if [ -e $SETUP_DIR/master/rotations-9.txt ] ; then
  cat $SETUP_DIR/master/rotations-9.txt | sed 's/, /,/g' | awk -F\, '{ print $1-1","$2-1","$3-1","$4-1","$5-1","$6-1","$7-1","$8-1","$9-1 }' >	$EVACS_HOME/var/www/html/data/Rotations-9
fi
cat $SETUP_DIR/master/electorates.txt | sed 's/, /,/g' > $EVACS_HOME/var/www/html/data/electorate_details
cat $SETUP_DIR/master/pollingplaces.txt | sed 's/, /,/g' > $EVACS_HOME/var/www/html/data/PollingPlaces
cat $SETUP_DIR/master/batches.txt | sed 's/, /,/g' > $EVACS_HOME/var/www/html/data/BatchDetails
rm -rf $EVACS_HOME/var//www/html/data/BarcodeNumbers
for x in `cat $SETUP_DIR/master/barcodes.txt | sed 's/ //g'`
do
  el=`echo $x | cut -d\, -f1`
  pp=`echo $x | cut -d\, -f2`
  count=`echo $x | cut -d\, -f3`
  # SIPL 2011-09-15: Added support for the optional pre-polling field
  #   in pollingplaces.txt.
  # ppname=`grep ",$pp," $EVACS_HOME/var/www/html/data/PollingPlaces | cut -d\, -f1`
  num_col=`grep ",$pp," $EVACS_HOME/var/www/html/data/PollingPlaces | awk -F\, '{ print NF }'`

  ppname=`grep ",$pp," $EVACS_HOME/var/www/html/data/PollingPlaces | cut -d\, -f1`
  if [[ $num_col -eq 4 &&
        $pp -eq `grep ",$pp," $EVACS_HOME/var/www/html/data/PollingPlaces | cut -d\, -f3` ]]; then
      ppname="$ppname $PREPOLL"
  fi

# SIPL 2014-03-18 Fixed the following line, which did not work
#   if there were 5 or more electorates specified.
  elname=`grep "^$el,"  $EVACS_HOME/var/www/html/data/electorate_details | cut -d\, -f2`
  if [ "x$ppname" == "x" ]; then
    bailout "Polling Place Number $pp does not exist - please amend the barcodes.txt file"
  fi
  if [ "x$elname" == "x" ]; then
    bailout "Electorate Number $el does not exist - please amend the barcodes.txt file"
  fi
  echo $ppname","$elname","$count >> $EVACS_HOME/var/www/html/data/BarcodeNumbers
done
# SIPL 2011-09-15 gen_barcodes_bin reads BarcodeNumbers
#   from the current directory, not /root.
#if [ -d $EVACS_HOME/root ] ; then
#  cp $EVACS_HOME/var/www/html/data/BarcodeNumbers 	$EVACS_HOME/root/BarcodeNumbers #this is where gen_barcodes_bin will look for it!
  cp -f $EVACS_HOME/var/www/html/data/BarcodeNumbers 	./BarcodeNumbers #this is where gen_barcodes_bin will look for it!
#fi


announce Populating Database, please wait...
echo Populating robson_rotation_5
log Populating robson_rotation_5
echo "COPY robson_rotation_5 FROM stdin;" > $EVACS_SCRATCH
cat $EVACS_HOME/var/www/html/data/Rotations-5 | sed 's/\r//g' | grep -v "^$" | sed 's/\t//g' | awk ' { print NR"\t{" $1 a"}"  }' >> $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror
cat $EVACS_HOME/var/www/html/data/Rotations-5 | sed 's/\r//g' | grep -v "^$" | awk ' END { print "CREATE SEQUENCE robson_5_seq start 0 increment 1 maxvalue " NR-1 " minvalue 0 cache 1 cycle;" } ' > $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

echo Populating robson_rotation_7
log Populating robson_rotation_7
echo "COPY robson_rotation_7 FROM stdin;" > $EVACS_SCRATCH
cat $EVACS_HOME/var/www/html/data/Rotations-7 | sed 's/\r//g' | grep -v "^$" | sed 's/\t//g' | awk ' { print NR"\t{" $1 a"}"  }' >> $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror
cat $EVACS_HOME/var/www/html/data/Rotations-7 | sed 's/\r//g' | grep -v "^$" | awk ' END { print "CREATE SEQUENCE robson_7_seq start 0 increment 1 maxvalue " NR-1 " minvalue 0 cache 1 cycle;" } ' > $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

# 2014-02-07 Support rotations-9.txt, if present.
if [ -e $SETUP_DIR/master/rotations-9.txt ] ; then
  echo Populating robson_rotation_9
  log Populating robson_rotation_9
  echo "COPY robson_rotation_9 FROM stdin;" > $EVACS_SCRATCH
  cat $EVACS_HOME/var/www/html/data/Rotations-9 | sed 's/\r//g' | grep -v "^$" | sed 's/\t//g' | awk ' { print NR"\t{" $1 a"}"  }' >> $EVACS_SCRATCH
  su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
  checkerror
  cat $EVACS_HOME/var/www/html/data/Rotations-9 | sed 's/\r//g' | grep -v "^$" | awk ' END { print "CREATE SEQUENCE robson_9_seq start 0 increment 1 maxvalue " NR-1 " minvalue 0 cache 1 cycle;" } ' > $EVACS_SCRATCH
  su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
  checkerror
fi

echo Populating master_data
log Populating master_data
echo "COPY master_data (election_name, election_date) FROM stdin;" > $EVACS_SCRATCH
name=`cat $EVACS_HOME/var/www/html/data/master-data.txt | sed 's/\r//g' | grep -v "^$" | sed 's/\t//g' | head -1`
date=`cat $EVACS_HOME/var/www/html/data/master-data.txt | sed 's/\r//g' | grep -v "^$" | sed 's/\t//g' | tail -1`
echo $name"	"$date >> $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

echo Populating electorate
log Populating electorate
echo "COPY electorate FROM stdin;" > $EVACS_SCRATCH
cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | sed 's/	//g' | awk -F\, ' { print $1"\t"$2"\t"$3"\t0\tarial\t000000\t99ffff\t16\t0\t0"  }' >> $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

echo Populating polling_place
log Populating polling_place
echo "COPY polling_place FROM stdin;" > $EVACS_SCRATCH
# SIPL 2011-08-29: Added support for an optional field to specify
#   a distinct polling place code for pre-polling.
#   For example, instead of:
#   Belconnen,80,2
#   Belconnen (Pre-Poll),103,2
#   now you can (and should) specify:
#   Belconnen,80,103,2
# This causes two rows to be added to polling_place:
#   80   103  "Belconnen"             f  2
#   103  -1   "Belconnen (Pre-Poll)"  f  2
# 
# The following line was:
#cat $EVACS_HOME/var/www/html/data/PollingPlaces | sed 's/\r//g' | grep -v "^$" | sed 's/	//g' | awk -F\, ' { print $2"\t"$1"\tf\t"$3}' >> $EVACS_SCRATCH
cat $EVACS_HOME/var/www/html/data/PollingPlaces | sed 's/\r//g' | \
  grep -v "^$" | sed 's/	//g' | \
  awk -F\, -v PREPOLL="$PREPOLL" '
  { if (NF == 3) { print $2"\t-1\t"$1"\tf\t"$3 }
    else if (NF == 4) {
      if ($3 == "") { print $2"\t-1\t"$1"\tf\t"$4 }
      else { print $2"\t"$3"\t"$1"\tf\t"$4 ; print $3"\t-1\t"$1" "PREPOLL"\tf\t"$4}
    }
  }' \
  >> $EVACS_SCRATCH
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

echo Populating batch
log Populating batch
echo "COPY batch FROM stdin;" > $EVACS_SCRATCH
BATCHDETAILS_TEMP=/tmp/BatchDetails-temp
rm -f $BATCHDETAILS_TEMP
cat $EVACS_HOME/var/www/html/data/BatchDetails | sed 's/\r//g' | sed 's/	//g' | grep -v "^$" > $BATCHDETAILS_TEMP
lines=`cat $BATCHDETAILS_TEMP | wc -l`
for (( i=1; $lines +1 -$i ; i++ )); do
    batch=`head -$i $BATCHDETAILS_TEMP | tail -1`
    if [ "x$batch" == "x" ]; then
      break;
    fi
    polling_place=`echo $batch | awk -F\, '{ print $2 }'`
    electorate=`echo $batch | awk -F\, '{ print $1 }'`
    range=`echo $batch | awk -F\, '{ print $3 }'`
    start=`echo $range | cut -d"-" -f1`
    end=`echo $range | cut -d"-" -f2`
    for ((count=$start ; $end +1 -$count ; count++ )); do
       echo $count"	"$polling_place"	"$electorate"	50	n" >> $EVACS_SCRATCH
    done
done
rm -f $BATCHDETAILS_TEMP
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror


echo
echo
echo
announce  eVacs Election Data Setup Phase-1 completed successfully!
log eVacs Election Data Setup Phase-1 completed successfully!
rm -f $EVACS_SCRATCH $EVACS_ERRLOG  2>/dev/null
eject $CDROM_DEVICE
echo
echo
echo
echo You may generate the barcodes now
echo
echo

exit 0
