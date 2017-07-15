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

# Script for Phase-2 of the Election Data Setup.
#-----------------------------------------------
# Phase-2 requires the following directory structure:
#
#  images/
#       |-- electorates.txt
#       |
#       |-- electorates
#       |       |------ *
#       |               |------ groups.txt
#       |              	|------ candidates.txt
#       |
#       |-- numbers
#       |       |------ *
#       |
#       |-- messages
#       |       |------ languages.txt
#       |       |------ *
#       |       	|------ *
#       |
#       |-- data_entry
#              |------ *
#       
#  audio/
#       |-- electorates
#       |       |------ *
#       |               |------ *
#       |               	|------ *
#       |
#       |-- numbers
#       |       |------ *
#       |
#       |-- letters
#       |       |------ *
#       |
#	|-- messages
#              |-- *.raw
#       
#

# All constants for this file are defined up here.
SETUP_DIR=/tmp/setup    # Scratch directory
LOG_FILE=$SETUP_DIR/Phase-2.$$.log  #  Log File for Setup Phase-2
MOUNT_OPTIONS=" -tiso9660 -o uid=`id -u postgres`"

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

echo "eVACS v2.0 Elections Data Setup Phase-2"


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
      if [[ $2 == "stay_up" ]] ; then

#       This code is to permit accessing early versions of the
#        Setup Phase II CDs, which do not have specific audio files.
#       The following warnings should not be seen when performing
#        the Setup Phase II functionality.

        warn "Required File : $1 is bad or missing."
        warn "Please create and load another Phase II CD."
      else
        bailout "Required File : $1 is bad. Exiting."
      fi
   fi
}


checkdir()
{
   if [ ! -d $1 ] ; then
        bailout "Required Directory $1 not found. Exiting."
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
# SIPL 2011-07-07: Support for split groups
# SIPL 2011-09-23: Delete in an order that respects the foreign
#                  key constraints.
      su postgres -c "psql evacs 2>/dev/null << EOF
delete from column_splits;
delete from candidate;
delete from party;
EOF" 
      bailout "Error while populating the database. Most Probable Cause: Data in setup files."
    fi
}

capitalize()
{
  letter=`echo $1 | cut -c1`
  rest=`echo $1 | cut -c2-`
  cap=`echo $letter | tr a-z A-Z`
  echo $cap$rest
}

splitline()
{
string=`echo $*`
len=`echo "$string" | wc -c`
count1=$(($len/2))
while [ $count1 -lt $len ]
do
  char=`echo "$string" | cut -c $count1`
  if [ -s $char ]
  then
    break;
  fi
  count1=$(($count1+1))
done
count2=$(($len/2))
while [ $count2 -gt 0 ]
do
  char=`echo "$string" | cut -c $count2`
  if [ -s $char ]
  then
    break;
  fi
  count2=$(($count2-1))
done
mid=$(($len/2))
if [ $(($count1-$mid)) -gt $(($mid-$count2)) ]
then
  echo "$string" | cut -c 1-$count2
  echo "$string" | cut -c $(($count2+1))-
else
  echo "$string" | cut -c 1-$count1
  echo "$string" | cut -c $(($count1+1))-
fi
}

splitparty()
{
string=`echo $*`
len=`echo "$string" | wc -c`
count1=$(($len/2))
while [ $count1 -lt $len ]
do
  char=`echo "$string" | cut -c $count1`
  if [ -s $char ]
  then
    break;
  fi
  count1=$(($count1+1))
done
count2=$(($len/2))
while [ $count2 -gt 0 ]
do
  char=`echo "$string" | cut -c $count2`
  if [ -s $char ]
  then
    break;
  fi
  count2=$(($count2-1))
done
mid=$(($len/2))
if [ $(($count1-$mid)) -gt $(($mid-$count2)) ]
then
  rest=`echo "$string" | cut -c $(($count2+1))-`
  echo `echo "$string" | cut -c 1-$count2`"@@@$rest"
else
  rest=`echo "$string" | cut -c $(($count1+1))-`
  echo `echo "$string" | cut -c 1-$count1`"@@@$rest"
fi
}


# Create the Scratch Directory and Log File
createdir $SETUP_DIR
rm -rf $SETUP_DIR/images $SETUP_DIR/images.1024 $SETUP_DIR/images.1280 $SETUP_DIR/audio
touch $EVACS_ERRLOG
chmod o+rw $EVACS_ERRLOG
log eVacs Election Data Setup Phase-2 initiated!

if [ -z $EVACS_HOME ] ; then
  bailout "Please set environment variable EVACS_HOME before proceeding with setup!"
fi


# Verify that Phase-1 was run
log Checking for Phase-1...
y=`su postgres -c "psql template1 2>$EVACS_ERRLOG << EOF
select datname from pg_database where datname='evacs';
EOF" `
if [ -s $EVACS_ERRLOG ] ; then
  bailout "Could not access database. Is PostMaster running?"
fi

if [ `echo $y | grep "1 row" | wc -l` -eq 1 ] ; then  #database exists
  # check if the database has the master_data table.
  z=`su postgres -c "psql evacs 2>/dev/null <<EOF
     select * from pg_tables where tablename='master_data';
EOF" `

  if [ `echo $z | grep "1 row" | wc -l` -eq 1 ] ; then   # eVACS 2.0 database exists
    log Evacs v2.0 database found!
  else                
    bailout "Please run Phase-1 of the Election Data Setup first!"
  fi

else
  bailout "Please run Phase-1 of the Election Data Setup first!"
fi

load_evacs_cdrom "Please insert Phase-2 Data Setup CD and press ENTER."
RETRY=0
while  [ ! -d $CDROM_DIRECTORY/audio ]; do
	 let RETRY=$RETRY+1
    warn "Loaded CD does not contain an \"audio\" directory"
    umount $CDROM_DEVICE 2>&1 > /dev/null
    eject $CDROM_DEVICE
    if [ $RETRY == 3 ] ; then
        bailout "Loaded CD does not contain an \"audio\" directory. Loading failed"
    fi
    instruct "Please insert Phase-2 Data Setup CD and press ENTER."
    read -s
    delete_instruction
    announce "CD Loading                                                                     "
    load_evacs_cdrom "Please insert Phase-2 Data Setup CD and  press ENTER."
done

RETRY=0
while  [ ! -d $CDROM_DIRECTORY/images ]; do
	 let RETRY=$RETRY+1
    warn "Loaded CD does not contain an \"images\" directory"
    umount $CDROM_DEVICE 2>&1 > /dev/null
    eject $CDROM_DEVICE
    if [ $RETRY == 3 ] ; then
        bailout "Loaded CD does not contain an \"images\" directory. Loading failed"
    fi
    instruct "Please insert Phase-2 Data Setup CD and press ENTER."
    read -s
    delete_instruction
    announce "CD Loading                                                                     "
    load_evacs_cdrom "Please insert Phase-2 Data Setup CD and  press ENTER."
done

rm -rf $SETUP_DIR/audio $SETUP_DIR/images
cp -R $CDROM_DIRECTORY/audio $SETUP_DIR
cp -R $CDROM_DIRECTORY/images $SETUP_DIR
cp -R $CDROM_DIRECTORY/images $SETUP_DIR/images.1024
cp -R $CDROM_DIRECTORY/images $SETUP_DIR/images.1280
chmod -R 777 $SETUP_DIR/audio $SETUP_DIR/images $SETUP_DIR/images.1024 $SETUP_DIR/images.1280
if [ $? != 0 ]; then
  umount $CDROM_DIRECTORY
  bailout  "Could not read from the CD, perhaps it is corrupt"
fi


umount $CDROM_DIRECTORY

#check if the candidate data already exists in the DB
rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(*) from candidate;
EOF" | cut -d'(' -f1`  
c_rows=`echo $rows | sed 's/count ------- //g'` 


rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(*) from party;
EOF" | cut -d'(' -f1`
p_rows=`echo $rows | sed 's/count ------- //g'` 

if [[ $c_rows -gt 0 || $p_rows -gt 0 ]] ; then
  echo
  echo "Candidate / Party data already exists in the database. Phase-2 has already been run."
  echo "If you continue, existing data will be lost and new data will be loaded."
  echo "Press Y to continue, any other key to abort."
  read ans
  echo
  if [[ "$ans" == "Y" || "$ans" == "y" ]] ; then
    # SIPL 2011-07-07: Now also clear out the column_splits table.
    # SIPL 2011-09-23: Delete from column_splits first,
    #                  to respect the foreign key constraint.
    su postgres -c "psql evacs 2>$EVACS_ERRLOG <<EOF
    delete from column_splits;
EOF"

    if [ -s $EVACS_ERRLOG ] ; then
      bailout "Could not delete data from the Column split table. Login as root and retry."
    fi

    su postgres -c "psql evacs 2>$EVACS_ERRLOG <<EOF
    delete from candidate;
EOF"

    if [ -s $EVACS_ERRLOG ] ; then
      bailout "Could not delete data from the Candidate table. Login as root and retry."
    fi

    su postgres -c "psql evacs 2>$EVACS_ERRLOG <<EOF
    delete from party;
EOF"

    if [ -s $EVACS_ERRLOG ] ; then
      bailout "Could not delete data from the Party table. Login as root and retry."
    fi
  else
    bailout "Aborting Phase-2 on user request."
  fi
fi


# Sanity check
log "Validating Election Setup Data...."
echo "Validating Election Setup Data, please wait..."
if [ ! -r $EVACS_HOME/var/www/html/data/electorate_details ] || [ ! -s $EVACS_HOME/var/www/html/data/electorate_details ] ; then
    bailout "Please run Phase-1 of the Election Data Setup first!"
fi


if [ ! -d "$SETUP_DIR/images" ]; then
    bailout "The \"images\" directory was not correctly read from the CD"
else
    checkdir $SETUP_DIR/images/messages

    echo "Updating Electorate Information..."
    log "Updating Electorate Information"
    checkfile $SETUP_DIR/images/electorates.txt
    # SIPL 2014-05-19 Support electorate names with non-alphanumeric characters
    OLDIFS=$IFS
    IFS=$'\n'
    for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | cut -d\, -f1-3 `
    do
      if [ `grep $x $SETUP_DIR/images/electorates.txt | wc -l` -ne 1 ]; then
        bailout "electorates.txt is not in synch with the electorates.txt file supplied in Phase-1!"
      fi
      if [ `cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | wc -l` -ne `cat $SETUP_DIR/images/electorates.txt | sed 's/\r//g' | grep -v "^$" | wc -l` ]; then
        bailout "electorates.txt is not in synch with the electorates.txt file supplied in Phase-1!"
      fi
    done
    IFS=$OLDIFS
    cp -f $SETUP_DIR/images/electorates.txt $EVACS_HOME/var/www/html/data/electorate_details 
    cat /dev/null > $EVACS_SCRATCH
    cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | sed 's/   //g' | awk -F\, ' { print "UPDATE electorate set number_of_electors="$4", font_name=\""$5"\", fg_colour=\""$6"\", bg_colour=\""$7"\", font_size="$8", number_of_cols="$9", number_of_rows="$10" where code="$1" ;"  }' >> $EVACS_SCRATCH
    cat $EVACS_SCRATCH | tr \" \' > "$EVACS_SCRATCH.tmp"
    mv -f "$EVACS_SCRATCH.tmp" $EVACS_SCRATCH
    su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
    checkerror


    echo "Checking Image Files..."
    log "Checking Image Files"
    checkfile $SETUP_DIR/images/messages/languages.txt
    num_languages=`cat $SETUP_DIR/images/messages/languages.txt | sed 's/\r//g' | grep -v "^$" | wc -l`
    for (( q = 1 ; $num_languages - $q ; q++ )) ; do
    	checkdir $SETUP_DIR/images/messages/$q
    done
    checkdir $SETUP_DIR/images/numbers
    checkfile $SETUP_DIR/images/numbers/blank.png
    checkdir $SETUP_DIR/images/electorates

    for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | cut -d\, -f1`
    do
        checkdir ${SETUP_DIR}/images/electorates/${x}
        checkfile ${SETUP_DIR}/images/electorates/${x}/groups.txt
        checkfile ${SETUP_DIR}/images/electorates/${x}/candidates.txt
    done
    checkdir $SETUP_DIR/images/data_entry
    checkfile $SETUP_DIR/images/data_entry/cancel.png
    checkfile $SETUP_DIR/images/data_entry/finish.png
fi

                                                                                                                                                             
echo Checking audio files...  
log Checking audio files  
if [ ! -d "$SETUP_DIR/audio" ]; then
    bailout "Election Data Setup Phase-2 CD must contain an \"audio\" directory"
else
    checkdir $SETUP_DIR/audio/messages
    checkfile $SETUP_DIR/audio/messages/ack.raw
    checkfile $SETUP_DIR/audio/messages/barcode_error.raw
    checkfile $SETUP_DIR/audio/messages/down_key.raw
    checkfile $SETUP_DIR/audio/messages/error.raw
    checkfile $SETUP_DIR/audio/messages/finish_key.raw
    checkfile $SETUP_DIR/audio/messages/formal2.raw
    checkfile $SETUP_DIR/audio/messages/formal.raw
    checkfile $SETUP_DIR/audio/messages/hidden.raw
    checkfile $SETUP_DIR/audio/messages/informal.raw
    # 2014-03-17 Require audio for new informal confirmation screens
    checkfile $SETUP_DIR/audio/messages/informal_stage_1.raw
    checkfile $SETUP_DIR/audio/messages/informal_stage_2.raw
    checkfile $SETUP_DIR/audio/messages/intro.raw
    checkfile $SETUP_DIR/audio/messages/next_key.raw
    checkfile $SETUP_DIR/audio/messages/not_started_again.raw
    checkfile $SETUP_DIR/audio/messages/previous_key.raw
    checkfile $SETUP_DIR/audio/messages/select_key.raw
    checkfile $SETUP_DIR/audio/messages/start_again_key.raw
    checkfile $SETUP_DIR/audio/messages/start_again_no.raw
    checkfile $SETUP_DIR/audio/messages/start_again_yes.raw
    checkfile $SETUP_DIR/audio/messages/started_again.raw
    checkfile $SETUP_DIR/audio/messages/undo_key.raw
    checkfile $SETUP_DIR/audio/messages/unused_key.raw
    checkfile $SETUP_DIR/audio/messages/up_key.raw
    checkfile $SETUP_DIR/audio/messages/volume_up.raw stay_up
    checkfile $SETUP_DIR/audio/messages/volume_down.raw stay_up
    checkdir $SETUP_DIR/audio/numbers
    checkdir $SETUP_DIR/audio/letters
    checkdir $SETUP_DIR/audio/electorates
    for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | cut -d\, -f1`
    do
        checkfile ${SETUP_DIR}/audio/electorates/${x}.raw
        checkdir ${SETUP_DIR}/audio/electorates/${x}
        for y in `cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | cut -d\, -f2 `
        do
          checkfile ${SETUP_DIR}/audio/electorates/${x}/${y}.raw
          checkdir ${SETUP_DIR}/audio/electorates/${x}/${y}
        done
        for z in `cat ${SETUP_DIR}/images/electorates/${x}/candidates.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_' `
        do
	  group=`echo $z | cut -d\, -f1`
          cand=`echo $z | cut -d\, -f3`
          checkfile ${SETUP_DIR}/audio/electorates/${x}/${group}/${cand}.raw
        done
    
    done
fi


# Some additional work to be done in the images folder to create the required directory structure:
echo Organising Files...  
log Organising Files  

# SIPL 2011-07-07: Support split groups

# The number of extra fields in each group in groups.txt
declare -a num_groups_extra_fields

# The numbers in the extra fields in groups.txt defining split groups
declare -a groups_extra_fields

# The number of candidates in each group in candidates.txt
declare -a num_candidates

# The number of physical columns in each group
declare -a num_physical_columns


# For each group, the total number of candidates, not including those
# in the last physical column for that group.  (For a group occupying
# only one physical column, the value will be 0.)
declare -a num_non_last_column_candidates

# The number of fields of a line in groups.txt if there is no
# specification of split groups
num_groups_fields_non_split=5

for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep -v "^$" | cut -d\, -f1`
do
  num_groups_extra_fields=()
  groups_extra_fields=()
  num_candidates=()
  num_physical_columns=()
  num_non_last_column_candidates=()

  # Get the number of seats, the number of rows and the number of columns
  # from electorates.txt, which has been copied to 
  # $EVACS_HOME/var/www/html/data/electorate_details)
  # SIPL 2014-03-19 Changed grep of "^$x" to "^$x," for forward
  #   compatibility (i.e., in case the electorate code can occupy
  #   more than one digit).
  num_seats=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f3 `
  num_rows=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f10 `
  num_cols=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f9 `
  
  # Used to check any if group is split across rows
  # physical_column_cursor=0
  total_physical_columns=0

  # Get the number of groups within this electorate from $x/groups.txt
  num_groups=`cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$"| wc -l`

  # Get the number of candidates in each group
  for ((p=0; $p < $num_groups; p++))
  do 
      num_candidates[$p]=`cat $SETUP_DIR/images/electorates/$x/candidates.txt | sed 's/\r//g' | cut -d\, -f1 | grep "^$(($p+1))\$" | wc -l`
  done
  
  for row in `cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_' `
  do
    # Get the index of this row (group)
    # This index starts from 1.
    group_index=`echo "$row" | cut -d\, -f2`

    # Get the number of fields in this row (group)
    # The newline from the echo adds 1 character, to give the correct result.
    num_fields=`echo "$row" | sed 's/[^,]//g' | wc -m`

    # If there are extra fields, the total number of extra fields
    # is the number of physical columns for the group.
    # If there are no extra fields, the group occupies only one
    # physical column.
    num_groups_extra_fields[$(($group_index-1))]=$(($num_fields-$num_groups_fields_non_split))

    if [ ${num_groups_extra_fields[$(($group_index-1))]} -eq 1 ]; then
      echo "Electorate $x, group $group_index, file groups.txt."
      echo "Exactly 1 extra field specified for this group."
      echo "Remove this extra field, or specify more extra fields"
      echo "for this group to split it into multiple columns."
      bailout "The number of extra fields in groups.txt may not be 1."
    fi
    
    # Set the number of physical columns in this group for later use.
    if [ ${num_groups_extra_fields[$(($group_index-1))]} -eq 0 ]; then
      num_physical_columns[$(($group_index-1))]=1
    else 
      num_physical_columns[$(($group_index-1))]=${num_groups_extra_fields[$(($group_index-1))]}
    fi

    # SIPL 2011-07-07 New code, commented out for now.
    #   The following code checks that the group has been split
    #   into the appropriate number of columns.  This has not
    #   (yet) been requested by the customer.  Uncomment this code
    #   if it is subsequently requested.
    # # Calculate the correct number of physical columns
    # correct_num_physical_columns=$((
    #     ( ${num_candidates[$(($group_index-1))]} + $num_seats - 1)
    #     / $num_seats))

    # # Check the number of extra fields is correct
    # if [ ${num_physical_columns[$(($group_index-1))]} -ne $correct_num_physical_columns ]; then 
    #   echo "Electorate $x, group $group_index, file groups.txt."
    #   bailout "The number of extra fields is not correct."
    # fi

    # Get the numbers in the extra fields if there are any
    total_candidates_in_extra_fields=0
    if [ ${num_groups_extra_fields[$(($group_index-1))]} -gt 0 ]; then
      for (( z = 0 ; $z < ${num_groups_extra_fields[$(($group_index-1))]} ; z++ )) ; 
      do
        groups_extra_fields[$z]=`echo "$row" | cut -d\, -f"$(($num_groups_fields_non_split+$z+1))"`

        # Check no number in the extra fields is greater than number of seats
        if [ ${groups_extra_fields[$z]} -gt $num_seats ]; then
           echo "Electorate $x, group $group_index, file groups.txt."
           echo "The number of candidates in a physical column can not be"
           echo "greater than the number of seats in the electorate."
           bailout "Too many candidates in a physical column."
        fi

        # Add up the number of candidates in each extra field.
        total_candidates_in_extra_fields=$((total_candidates_in_extra_fields+${groups_extra_fields[$z]}))

        # Save the number of candidates in the last physical column
        # for later use.
        num_candidates_last_column=${groups_extra_fields[$z]}
      done

      # Check that the numbers in the extra fields add up
      # to the number of candidates in this group.
      if [ $total_candidates_in_extra_fields -ne ${num_candidates[$(($group_index-1))]} ]; then
        echo "Electorate $x, group $group_index, files groups.txt"
        echo "and/or candidates.txt."
        echo "The numbers in the extra fields of this group do not add up"
        echo "to the total number of candidates in this group."
        bailout "Incorrect number of candidates specified."
      fi
      # Save the number of candidates that are not in the last physical column for later use.
      num_non_last_column_candidates[$(($group_index-1))]=$((${num_candidates[$(($group_index-1))]}-$num_candidates_last_column))
    # SIPL 2012-01-30: Add check: if no split is specified,
    # the number of candidates must not be greater than the number of seats 
    else
	if [ ${num_candidates[$(($group_index-1))]} -gt $num_seats ]; then
           echo "Electorate $x, group $group_index, file groups.txt."
           echo "The number of candidates in this group is"
           echo "greater than the number of seats in the electorate."
           echo "This group must be split."
           bailout "Too many candidates in one physical column."
	fi
    fi

    # Check no group can be split across rows
    # If the next group can not fit in this row,
    # it can jump to the next row and leave the 
    # rest of the current row blank.
    # Therefore, there is no need to run the following check.
    
    #  let physical_column_cursor+=num_physical_columns[group_index-1]
    #  if [ $physical_column_cursor -gt $num_cols ]; then
    #    bailout "No group is allowed to be split across rows."
    #  fi
    #  let physical_column_cursor%=num_cols

    if (( num_physical_columns[group_index-1] > num_cols )); then
        echo "Electorate $x, group $group_index, files groups.txt"
        echo "and/or electorates.txt."
        bailout "This group occupies too many physical columns."
    fi

    if (( (total_physical_columns % num_cols) +
          num_physical_columns[group_index-1] > num_cols )); then
      # Increase total_physical_columns to fill up the current row.
      # No need to add as many as num_cols in the next line; could
      # add just num_physical_columns[group_index-1].
      let temp_total_physical_columns=total_physical_columns+num_cols
      let total_physical_columns=$(( temp_total_physical_columns -
          (temp_total_physical_columns % num_cols) ))
    fi
    let total_physical_columns+=num_physical_columns[group_index-1]

  done

  # SIPL 2014-03-19 Changed grep of "^$x" to "^$x," for forward
  #   compatibility (i.e., in case the electorate code can occupy
  #   more than one digit).
  font_name=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f5 `
  font_name=`capitalize $font_name`
  fg_colour=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f6 `
  bg_colour=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f7 `
  font_size=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f8 `
  num_rows=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f10 `
  num_cols=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f9 `
  seats=`cat $EVACS_HOME/var/www/html/data/electorate_details | sed 's/\r//g' | grep "^$x," | cut -d\, -f3 `
  num_blocks=0;
  img_height=$((720/(${num_rows}*$((${seats}+1)))));
  img_height_1024=$((642/(${num_rows}*$((${seats}+1)))));
  img_width=$((1152/${num_cols})); #width of group label
  img_width_1024=$((1024/${num_cols})); #width of group label
  # SIPL 2011-07-07:  (Note on existing code.)
  #   Leave room for (square) box at the left-hand-side of the candidate label
  img_width2=$((${img_width}-${img_height})); # width of candidate label
  img_width2_1024=$((${img_width_1024}-${img_height_1024})); # width of candidate label

# Why 720 and 642 above?
# They seem to be about 5/6ths of the height of the corresponding display,
# in pixels - but not exactly!  768*5/6 = 640, not 642.
# It seems the heading images are 1152x144 pixels, and
# 864-144=720.
# When scaled by 88.88%, the heading image is now 1024x128 pixels,
# and 768-128=640.
# For 1280x1024, scaling is 111.11% in the horizontal,
# and 118.52% in the vertical.
# When scaled by 111.11%, the heading image is 1280x160 pixels,
# and 1024-160=864.  So we use 864 in the calculation of img_height_1280.
# Further on in the code, where the scale factor "88/99" (= 88.88%) is
# used for 1024x768, we use "10/9" (= 111.11%) for 1280x1024.
# Instead of "88/99", the original author could have written "8/9"
# (or even "1024/1152").

  img_height_1280=$((864/(${num_rows}*$((${seats}+1)))));
  img_width_1280=$((1280/${num_cols})); #width of group label
  img_width2_1280=$((${img_width_1280}-${img_height_1280})); # width of candidate label


#  adjust the size of the numbers to $img_heightx$img_height if required so that ballot papers look ok
   createdir $SETUP_DIR/images/$x/numbers
   createdir $SETUP_DIR/images.1024/$x/numbers
   createdir $SETUP_DIR/images.1280/$x/numbers
   if [ $img_height -eq 40 ]; then
    cp -f $SETUP_DIR/images/numbers/*.png $SETUP_DIR/images/$x/numbers
   else
     for num in `ls $SETUP_DIR/images/numbers/*.png | awk -F\/ '{print $NF}'`
     do
       convert -type palette -depth 8 -resize ${img_height}x${img_height} $SETUP_DIR/images/numbers/$num $SETUP_DIR/images/$x/numbers/$num
     done
   fi
   if [ $img_height_1024 -eq 40 ]; then
    cp -f $SETUP_DIR/images.1024/numbers/*.png $SETUP_DIR/images.1024/$x/numbers
   else
     for num in `ls $SETUP_DIR/images.1024/numbers/*.png | awk -F\/ '{print $NF}'`
     do
       convert -type palette -depth 8 -resize ${img_height_1024}x${img_height_1024} $SETUP_DIR/images.1024/numbers/$num $SETUP_DIR/images.1024/$x/numbers/$num
     done
   fi

   if [ $img_height_1280 -eq 40 ]; then
    cp -f $SETUP_DIR/images.1280/numbers/*.png $SETUP_DIR/images.1280/$x/numbers
   else
     for num in `ls $SETUP_DIR/images.1280/numbers/*.png | awk -F\/ '{print $NF}'`
     do
       convert -type palette -depth 8 -resize ${img_height_1280}x${img_height_1280} $SETUP_DIR/images.1280/numbers/$num $SETUP_DIR/images.1280/$x/numbers/$num
     done
   fi

  convert -size ${img_width}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" -draw "line $((${img_width}-1)),0 $((${img_width}-1)),${img_height}" ${SETUP_DIR}/images/electorates/${x}/blank.png
  convert -size ${img_width}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" -draw "line 0,0  $((${img_width}-1)),0" -draw "line $((${img_width}-1)),0 $((${img_width}-1)),${img_height}" ${SETUP_DIR}/images/electorates/${x}/blank-group.png
# SIPL 2011-07-07: Add blank-no-borders.png to support split groups for 1152
  convert -size ${img_width}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" ${SETUP_DIR}/images/electorates/${x}/blank-no-borders.png
  convert -size ${img_width_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" -draw "line $((${img_width_1024}-1)),0 $((${img_width_1024}-1)),${img_height_1024}" ${SETUP_DIR}/images.1024/electorates/${x}/blank.png
  convert -size ${img_width_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" -draw "line 0,0  $((${img_width_1024}-1)),0" -draw "line $((${img_width_1024}-1)),0 $((${img_width_1024}-1)),${img_height_1024}" ${SETUP_DIR}/images.1024/electorates/${x}/blank-group.png
# SIPL 2011-07-07: Add blank-no-borders.png to support split groups for 1024
  convert -size ${img_width_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" ${SETUP_DIR}/images.1024/electorates/${x}/blank-no-borders.png

  convert -size ${img_width_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" -draw "line $((${img_width_1280}-1)),0 $((${img_width_1280}-1)),${img_height_1280}" ${SETUP_DIR}/images.1280/electorates/${x}/blank.png
  convert -size ${img_width_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" -draw "line 0,0  $((${img_width_1280}-1)),0" -draw "line $((${img_width_1280}-1)),0 $((${img_width_1280}-1)),${img_height_1280}" ${SETUP_DIR}/images.1280/electorates/${x}/blank-group.png
# SIPL 2011-07-07: Add blank-no-borders.png to support split groups for 1280
  convert -size ${img_width_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -fill "#${fg_colour}" ${SETUP_DIR}/images.1280/electorates/${x}/blank-no-borders.png

  # SIPL 2012-02-07
  # Support shrinking of the group names on the confirmation screen
  # so that they are always visible in their entirety.
  # This is done on a per-electorate basis: all group names for
  # an electorate will be generated at the same size.
  # An additional loop has been added here to work out
  # what that size should be.
  # Start with $font_size (for 1152); the value can only decrease
  # from here on, as the loop encounters long group names.
  # (The font size for 1024 and 1280 is determined separately, rather
  # than merely being calculated from that determined for 1152.)
  confirmation_screen_group_font_size=$font_size
  confirmation_screen_group_font_size_1024=$((font_size*88/99))
  confirmation_screen_group_font_size_1280=$((font_size*10/9))
  # Maximum height allowed for the group name; this is $img_height
  # less the height of the row used for the candidate name, less
  # a five-pixel top margin. (Three-pixel margin used for 1024 and 1280,
  # based on how convert seems to work.)
  confirmation_screen_group_height=$((img_height-confirmation_screen_group_font_size-5))
  confirmation_screen_group_height_1024=$((img_height_1024-confirmation_screen_group_font_size_1024-3))
  confirmation_screen_group_height_1280=$((img_height_1280-confirmation_screen_group_font_size_1280-3))

  # This must be a loop over candidates.txt, not groups.txt, as the
  # candidates.txt file can contain group names too (for UNGROUPED
  # candidates).
  for line in `cat ${SETUP_DIR}/images/electorates/${x}/candidates.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_' `
  do
    real_name=`echo $line | cut -d\, -f2 | tr '_' ' ' | tr "'" "\\'" `
    group=`echo $line | cut -d\, -f1 `
    groupname=`grep "^[^,]*,${group}," $SETUP_DIR/images/electorates/$x/groups.txt | cut -d\, -f1 |  tr "'" "\\'" `
    # check for party names for ungrouped candidates
    if [ "$groupname" == "UNGROUPED" ] && echo $real_name | grep -q : ; then
	groupname=`echo $real_name | cut -d: -f2-`
    fi

    # Subtract 6 from img_width2, because the text will be drawn
    # for real with a five-pixel left margin,
    # and there is one pixel at the right hand side used for
    # the border.
    # (Whereas the top margin varies, the left margin is five pixels
    # for all of the three screen resolutions.)

    # Loop until the group name fits within the height allowed.
    while true; do
        group_height_used=$(convert \
          \( -pointsize $confirmation_screen_group_font_size \
          -size $((img_width2-6))x  -font $font_name \
          "caption:${groupname}" \) -format '%[height]' info: )
        if [[ $group_height_used -le $confirmation_screen_group_height ]]
	then
	    # It fits; no need to go any smaller.
	    break
	fi
	# Try a smaller size and go round again.
	let confirmation_screen_group_font_size--
    done

    # Same again for 1024.
    while true; do
        group_height_used_1024=$(convert \
          \( -pointsize $confirmation_screen_group_font_size_1024 \
          -size $((img_width2_1024-6))x  -font $font_name \
          "caption:${groupname}" \) -format '%[height]' info: )
        if [[ $group_height_used_1024 -le \
              $confirmation_screen_group_height_1024 ]]
	then
	    # It fits; no need to go any smaller.
	    break
	fi
	# Try a smaller size and go round again.
	let confirmation_screen_group_font_size_1024--
    done

    # Same again for 1280.
    while true; do
        group_height_used_1280=$(convert \
          \( -pointsize $confirmation_screen_group_font_size_1280 \
          -size $((img_width2_1280-6))x  -font $font_name \
          "caption:${groupname}" \) -format '%[height]' info: )
        if [[ $group_height_used_1280 -le \
              $confirmation_screen_group_height_1280 ]]
	then
	    # It fits; no need to go any smaller.
	    break
	fi
	# Try a smaller size and go round again.
	let confirmation_screen_group_font_size_1280--
    done

  done
  # End of SIPL 2012-02-07 additions.

# create the group and candidate images now
  for row in `cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_' `
  do
    y=`echo "$row" | cut -d\, -f2`
    createdir ${SETUP_DIR}/images/electorates/${x}/${y}
    createdir ${SETUP_DIR}/images.1024/electorates/${x}/${y}
    createdir ${SETUP_DIR}/images.1280/electorates/${x}/${y}
    letter=`echo "$row" | sed 's/\r//g' | cut -d\, -f4 `
    if [ -s $letter ]; then
      letter=" "
    fi
    party=`echo "$row" | cut -d\, -f1 | tr '_' ' ' | tr "'" "\\'" `
    group_font_size=`echo "$row" | sed 's/\r//g' | cut -d\, -f5 `

    echo Creating Image File for ${letter}   ${party}
    if [[ $group_font_size == "" ]]; then

#     This code is for backwards compatibility; i.e. to permit accessing earlier
#      Setup Phase II CDs. In other cases this section of code should not be executed.

      group_font_size="12"
      warn "ERROR: Group font size not spcified, setting size to ${group_font_size}."
    fi

    # SIPL 2011-07-07: Calculate the width of the group image according to 
    #                  the number of extra fields for this group.
    if [ ${num_groups_extra_fields[$(($y-1))]} -gt 1 ]; then
      img_group_width=$((${num_groups_extra_fields[$(($y-1))]} * $img_width))
      img_group_width_1024=$((${num_groups_extra_fields[$(($y-1))]} * $img_width_1024))
      img_group_width_1280=$((${num_groups_extra_fields[$(($y-1))]} * $img_width_1280))
    else
      img_group_width=$img_width
      img_group_width_1024=$img_width_1024
      img_group_width_1280=$img_width_1280
    fi

    num_blocks=$(($num_blocks+1))
    #changed for TIR 28
    #if [ $num_cols -gt 3 ]; then
    #
    # if the number of characters * the font_size is greater than img_width,
    # split the party name.
    #
    # chars * font_size gives a fairly pessimistic estimate of the upper bound
    # on the width of the string in pixels in most fonts. 3/4 gives a more
    # reasonable estimate.
    # SIPL 2011-07-07: Determine whether or not to split the party name
    #     according to the new width of the group image.
    if [ $((`echo $party | wc -c  | sed "s/^ *//" | cut -f1 -d" "`*$font_size*3/4)) -ge ${img_group_width} ]; then
      party=`splitparty "$party"`
      party2=`echo "$party" | sed 's/^.*@@@//'`
      party=`echo "$party" | sed 's/@@@.*$//'`
    fi
# SIPL 2011-07-07: Draw group images using img_group_width
convert -size ${img_group_width}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $group_font_size -fill "#${fg_colour}" -draw "text 5,${group_font_size} \"${letter}\"" -draw "text $((${img_height}+5)),${group_font_size} \"${party}\"" -draw "text $((${img_height}+5)),$((${group_font_size}+${group_font_size})) \"${party2}\"" -draw "line 0,0  $((${img_group_width}-1)),0" -draw "line $((${img_group_width}-1)),0 $((${img_group_width}-1)),${img_height}"  ${SETUP_DIR}/images/electorates/${x}/${y}.png
    convert -size ${img_group_width_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($group_font_size*88/99)) -fill "#${fg_colour}" -draw "text 5,${group_font_size} \"${letter}\"" -draw "text $((${img_height_1024}+5)),${group_font_size} \"${party}\"" -draw "text $((${img_height_1024}+5)),$((${group_font_size}+${group_font_size}*88/99)) \"${party2}\"" -draw "line 0,0  $((${img_group_width_1024}-1)),0" -draw "line $((${img_group_width_1024}-1)),0 $((${img_group_width_1024}-1)),${img_height_1024}"  ${SETUP_DIR}/images.1024/electorates/${x}/${y}.png

    convert -size ${img_group_width_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($group_font_size*10/9)) -fill "#${fg_colour}" -draw "text 5,${group_font_size} \"${letter}\"" -draw "text $((${img_height_1280}+5)),${group_font_size} \"${party}\"" -draw "text $((${img_height_1280}+5)),$((${group_font_size}+${group_font_size}*10/9)) \"${party2}\"" -draw "line 0,0  $((${img_group_width_1280}-1)),0" -draw "line $((${img_group_width_1280}-1)),0 $((${img_group_width_1280}-1)),${img_height_1280}"  ${SETUP_DIR}/images.1280/electorates/${x}/${y}.png

    party2=""
  done
  max_blocks=$(($num_cols*$num_rows))
  min_blocks=$(($num_cols*$(($num_rows-1))))
  if [ $num_blocks -gt $max_blocks ]; then
   announce "Electorate No. $x has $num_blocks Groups, but ballot paper is configured to show only $max_blocks." 
   announce "You may want to increase the rows ($num_rows) or columns ($num_cols) in the electorates.txt file for better results."
  fi
  if [ $num_blocks -lt $min_blocks ]; then
   announce "Electorate No. $x has only $num_blocks Groups, but ballot paper is configured to show upto $max_blocks." 
   announce "You may want to reduce the rows ($num_rows) or columns ($num_cols) in the electorates.txt file for better results."
  fi
  total_candidates=0
  for line in `cat ${SETUP_DIR}/images/electorates/${x}/candidates.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_' `
  do
    real_name=`echo $line | cut -d\, -f2 | tr '_' ' ' | tr "'" "\\'" `
    group=`echo $line | cut -d\, -f1 `
    # SIPL 2012-02-06 Next line was:
    #   groupname=`grep ",${group}," $SETUP_DIR/images/electorates/$x/groups.txt | cut -d\, -f1 |  tr "'" "\\'" `
    # But this no longer works in the presence of split groups, which
    # have extra numeric columns at the end.  So instead, make sure
    # the grep is always against the second column.
    groupname=`grep "^[^,]*,${group}," $SETUP_DIR/images/electorates/$x/groups.txt | cut -d\, -f1 |  tr "'" "\\'" `
    # check for party names for ungrouped candidates
    if [ "$groupname" == "UNGROUPED" ] && echo $real_name | grep -q : ; then
	groupname=`echo $real_name | cut -d: -f2-`
	real_name_temp=`echo $real_name | cut -d: -f1`
	real_name=`echo "$real_name_temp"; echo "$groupname"`
	with_group=`echo "$real_name_temp"; echo "$groupname"`
	# SIPL 2012-02-07 Keep the real name separate for use on the
	# confirmation screen.
	conf_screen_real_name=$real_name_temp
    else
	# SIPL 2012-02-07 Keep the real name separate for use on the
	# confirmation screen.
	conf_screen_real_name=$real_name
	with_group=`echo "$real_name"; echo "$groupname"`
    fi
    cid=`echo $line | sed 's/\r//g' | cut -d\, -f3 `
    echo Creating Image File for ${real_name} of ${groupname}
    # removed for TIR 28
    #if [ $num_cols -gt 4 ];q then
    #  real_name=`splitline "$real_name"`	
    #fi

    # SIPL 2011-07-07: Draw candidate images supporting split groups
    #     on the ballot.  (Leave the *-with-group.png images untouched;
    #     they appear on the confirmation screen.)
    
    if [ ${num_groups_extra_fields[$(($group-1))]} -gt 1 ]; then
      # For the candidates _not_ in the last physical column for the
      # group, do not draw the right-hand-side line.
      if [ $cid -le ${num_non_last_column_candidates[$(($group-1))]} ]; then
        convert -size ${img_width2}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $font_size -fill "#${fg_colour}" -draw "text 5,${font_size} \"${real_name}\"" ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}.png

        convert -size ${img_width2_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*88/99)) -fill "#${fg_colour}" -draw "text 5,$((${font_size}*88/99)) \"${real_name}\"" ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}.png

        convert -size ${img_width2_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*10/9)) -fill "#${fg_colour}" -draw "text 5,$((${font_size}*10/9)) \"${real_name}\"" ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}.png
      # For the candidates in the last physical column for the group,
      # do draw the right-hand-side line.
      else
        convert -size ${img_width2}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $font_size -fill "#${fg_colour}" -draw "text 5,${font_size} \"${real_name}\"" -draw "line $((${img_width2}-1)),0 $((${img_width2}-1)),${img_height}" ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}.png

        convert -size ${img_width2_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*88/99)) -fill "#${fg_colour}" -draw "text 5,$((${font_size}*88/99)) \"${real_name}\"" -draw "line $((${img_width2_1024}-1)),0 $((${img_width2_1024}-1)),${img_height_1024}" ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}.png

        convert -size ${img_width2_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*10/9)) -fill "#${fg_colour}" -draw "text 5,$((${font_size}*10/9)) \"${real_name}\"" -draw "line $((${img_width2_1280}-1)),0 $((${img_width2_1280}-1)),${img_height_1280}" ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}.png
      fi
    # If the group occupies only one physical column,
    # draw the right-hand-side line.
    else
      convert -size ${img_width2}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $font_size -fill "#${fg_colour}" -draw "text 5,${font_size} \"${real_name}\"" -draw "line $((${img_width2}-1)),0 $((${img_width2}-1)),${img_height}" ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}.png

      convert -size ${img_width2_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*88/99)) -fill "#${fg_colour}" -draw "text 5,$((${font_size}*88/99)) \"${real_name}\"" -draw "line $((${img_width2_1024}-1)),0 $((${img_width2_1024}-1)),${img_height_1024}" ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}.png

      convert -size ${img_width2_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*10/9)) -fill "#${fg_colour}" -draw "text 5,$((${font_size}*10/9)) \"${real_name}\"" -draw "line $((${img_width2_1280}-1)),0 $((${img_width2_1280}-1)),${img_height_1280}" ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}.png
    fi


    # SIPL 2012-02-07 New code for drawing the confirmation screen images.

    # First, use only the candidate name. The text is drawn with a top
    # and left margin of five pixels.
    convert -size ${img_width2}x${img_height} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $font_size -fill "#${fg_colour}" -gravity NorthWest -draw "text 5,5 \"${conf_screen_real_name}\"" -draw "line $((${img_width2}-1)),0 $((${img_width2}-1)),${img_height}"  ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-candidate-name.png
    # Now, draw the group name.  As above, subtract 6 because of
    # the five-pixel left margin and the one-pixel right border.
    convert \( -size $((img_width2-6))x -type palette -depth 8 -background "#${bg_colour}" -font $font_name -pointsize $confirmation_screen_group_font_size -fill "#${fg_colour}" "caption:${groupname}" \)  ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-group-name.png
    # Now paste the group name image on top of the candidate image.
    # Specify the five-pixel left margin, and use a top margin
    # which includes both the five-pixel top margin and the font size
    # used for the candidate name.
    composite -geometry "+5+$((font_size+5))" ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-group-name.png ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-candidate-name.png ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-with-group.png
    # Remove the separate candidate and group images;
    # they are no longer needed.
    rm -f ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-group-name.png ${SETUP_DIR}/images/electorates/${x}/${group}/${cid}-candidate-name.png

    # The confirmation screen image for 1024.
    # First, use only the candidate name. The text is drawn with a
    # left margin of five pixels and a top margin of three pixels.
    convert -size ${img_width2_1024}x${img_height_1024} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*88/99)) -fill "#${fg_colour}" -gravity NorthWest -draw "text 5,3 \"${conf_screen_real_name}\"" -draw "line $(((${img_width2_1024}-1))),0 $(((${img_width2_1024}-1))),${img_height_1024}"  ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-candidate-name.png
    # Now, draw the group name.  As above, subtract 6 because of
    # the five-pixel left margin and the one-pixel right border.
    convert \( -size $((img_width2_1024-6))x -type palette -depth 8 -background "#${bg_colour}" -font $font_name -pointsize $confirmation_screen_group_font_size_1024 -fill "#${fg_colour}" "caption:${groupname}" \)  ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-group-name.png
    # Now paste the group name image on top of the candidate image.
    # Specify the five-pixel left margin, and use a top margin
    # which includes both the three-pixel top margin and the font size
    # used for the candidate name.
    composite -geometry "+5+$((font_size*88/99+3))" ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-group-name.png ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-candidate-name.png ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-with-group.png
    # Remove the separate candidate and group images;
    #  they are no longer needed.
    rm -f ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-group-name.png ${SETUP_DIR}/images.1024/electorates/${x}/${group}/${cid}-candidate-name.png

    # The comment that was here, added 2008-07-29, has now been deleted,
    # as the code has been replaced with a new version on 2012-02-07.

    # The confirmation screen image for 1280.
    # First, use only the candidate name. The text is drawn with a
    # left margin of five pixels and a top margin of three pixels.
    convert -size ${img_width2_1280}x${img_height_1280} -type palette -depth 8 xc:"#${bg_colour}" -font $font_name -pointsize $(($font_size*10/9)) -fill "#${fg_colour}" -gravity NorthWest -draw "text 5,3 \"${conf_screen_real_name}\"" -draw "line $(((${img_width2_1280}-1))),0 $(((${img_width2_1280}-1))),${img_height_1280}"  ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-candidate-name.png
    # Now, draw the group name.  As above, subtract 6 because of
    # the five-pixel left margin and the one-pixel right border.
    convert \( -size $((img_width2_1280-6))x -type palette -depth 8 -background "#${bg_colour}" -font $font_name -pointsize $confirmation_screen_group_font_size_1280 -fill "#${fg_colour}" "caption:${groupname}" \)  ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-group-name.png
    # Now paste the group name image on top of the candidate image.
    # Specify the five-pixel left margin, and use a top margin
    # which includes both the three-pixel top margin and the font size
    # used for the candidate name.
    composite -geometry "+5+$((font_size*10/9+3))" ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-group-name.png ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-candidate-name.png ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-with-group.png
    # Remove the separate candidate and group images;
    # they are no longer needed.
    rm -f ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-group-name.png ${SETUP_DIR}/images.1280/electorates/${x}/${group}/${cid}-candidate-name.png

    # End of SIPL 2012-02-07 modifications.

    total_candidates=$(($total_candidates+1))
  done
  # Check that enough preference images and audio clips are available.
  for (( q = 0 ; $total_candidates - $q  ; q++ )) ; do
    checkfile $SETUP_DIR/images/numbers/$q.png
  done
  for (( q = 1 ; $total_candidates - $q  ; q++ )) ; do
    checkfile $SETUP_DIR/audio/numbers/$q.raw
  done
done

mv $SETUP_DIR/audio/messages/*.raw $SETUP_DIR/audio/
rm -rf $SETUP_DIR/audio/messages
rm -rf $SETUP_DIR/images/numbers
rm -rf $SETUP_DIR/images.1024/numbers
rm -rf $SETUP_DIR/images.1280/numbers

# Concatenate the sound clips for group name with the letter
for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | cut -d\, -f1`
do
  for row in `cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_' `
  do
    y=`echo "$row" | cut -d\, -f2`
    letter=`echo "$row" | sed 's/\r//g' | cut -d\, -f4 `
    # SIPL 2014-05-23 Preserve the original group audio for use on the confirmation screen
    cp -f $SETUP_DIR/audio/electorates/$x/${y}.raw $SETUP_DIR/audio/electorates/$x/${y}_original.raw
    if [ ! -s $letter ]; then
      if [ -f $SETUP_DIR/audio/letters/${letter}.raw ]; then
        cat $SETUP_DIR/audio/letters/${letter}.raw $SETUP_DIR/audio/electorates/$x/${y}.raw > $SETUP_DIR/audio/electorates/$x/${y}_temp.raw	
        mv -f $SETUP_DIR/audio/electorates/$x/${y}_temp.raw $SETUP_DIR/audio/electorates/$x/${y}.raw
      else 
        letter=`echo $letter | tr A-Z a-z`
        if [ -f $SETUP_DIR/audio/letters/${letter}.raw ]; then
          cat $SETUP_DIR/audio/letters/${letter}.raw $SETUP_DIR/audio/electorates/$x/${y}.raw > $SETUP_DIR/audio/electorates/$x/${y}_temp.raw	
          mv -f $SETUP_DIR/audio/electorates/$x/${y}_temp.raw $SETUP_DIR/audio/electorates/$x/${y}.raw
        else
          bailout "Audio Clip $letter.raw is required - please check the audio/letters/ directory of the setup data CD." 
        fi
      fi
    fi
  done
done


# The program uses index numbers starting from 0, so adjust the indexes accordingly:
for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | cut -d\, -f1`
do
  for y in `cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | cut -d\, -f2  | sort -n`
  do
  for z in `ls $SETUP_DIR/images/electorates/$x/$y | grep -v txt | grep -v TRANS | cut -d\. -f1 | cut -d\- -f1 | sort -u -n`
    do
      mv $SETUP_DIR/images/electorates/$x/$y/$z.png $SETUP_DIR/images/electorates/$x/$y/$(($z-1)).png
      mv $SETUP_DIR/images/electorates/$x/$y/$z-with-group.png $SETUP_DIR/images/electorates/$x/$y/$(($z-1))-with-group.png
      mv $SETUP_DIR/images.1024/electorates/$x/$y/$z.png $SETUP_DIR/images.1024/electorates/$x/$y/$(($z-1)).png
      mv $SETUP_DIR/images.1024/electorates/$x/$y/$z-with-group.png $SETUP_DIR/images.1024/electorates/$x/$y/$(($z-1))-with-group.png
      mv $SETUP_DIR/images.1280/electorates/$x/$y/$z.png $SETUP_DIR/images.1280/electorates/$x/$y/$(($z-1)).png
      mv $SETUP_DIR/images.1280/electorates/$x/$y/$z-with-group.png $SETUP_DIR/images.1280/electorates/$x/$y/$(($z-1))-with-group.png
    done
    mv $SETUP_DIR/images/electorates/$x/$y $SETUP_DIR/images/electorates/$x/$(($y-1))
    mv $SETUP_DIR/images/electorates/$x/$y.png $SETUP_DIR/images/electorates/$x/$(($y-1)).png
    mv $SETUP_DIR/images.1024/electorates/$x/$y $SETUP_DIR/images.1024/electorates/$x/$(($y-1))
    mv $SETUP_DIR/images.1024/electorates/$x/$y.png $SETUP_DIR/images.1024/electorates/$x/$(($y-1)).png
    mv $SETUP_DIR/images.1280/electorates/$x/$y $SETUP_DIR/images.1280/electorates/$x/$(($y-1))
    mv $SETUP_DIR/images.1280/electorates/$x/$y.png $SETUP_DIR/images.1280/electorates/$x/$(($y-1)).png
  done
done

for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | cut -d\, -f1`
do
  for y in `cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | cut -d\, -f2  | sort -n`
  do
  for z in `ls $SETUP_DIR/audio/electorates/$x/$y | grep -v TRANS | cut -d\. -f1 | sort -n`
    do
      mv $SETUP_DIR/audio/electorates/$x/$y/$z.raw $SETUP_DIR/audio/electorates/$x/$y/$(($z-1)).raw
    done
     mv $SETUP_DIR/audio/electorates/$x/$y $SETUP_DIR/audio/electorates/$x/$(($y-1))
     mv $SETUP_DIR/audio/electorates/$x/$y.raw $SETUP_DIR/audio/electorates/$x/$(($y-1)).raw
     # SIPL 2014-05-23 Preserve the original group audio for use on the confirmation screen
     mv $SETUP_DIR/audio/electorates/$x/${y}_original.raw $SETUP_DIR/audio/electorates/$x/$(($y-1))_original.raw
  done
done

for x in `cat $EVACS_HOME/var/www/html/data/electorate_details | cut -d\, -f1`
do
  # SIPL 2011-07-07: Support split groups.
  #   The previous version had:
  #     awk -F, '{ print $1","$2-1","$3","$4","$5 }'
  #   Now, there can be more than 5 columns, so a loop is needed.
  #   Subtract 1 from column 2, but print all other columns untouched.
  cat $SETUP_DIR/images/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" |  awk -F, '{ for (i=1; i<=NF; i++) { if (i == 2) { printf $i-1"," } else if (i==NF) { print $i } else { printf $i"," } } }' > $SETUP_DIR/images/electorates/$x/groups.txt.new

  mv -f $SETUP_DIR/images/electorates/$x/groups.txt.new $SETUP_DIR/images/electorates/$x/groups.txt
  cat $SETUP_DIR/images/electorates/$x/candidates.txt | sed 's/\r//g' | grep -v "^$" | awk -F, '{ print $1-1","$2","$3-1 }' > $SETUP_DIR/images/electorates/$x/candidates.txt.new 
  mv -f $SETUP_DIR/images/electorates/$x/candidates.txt.new $SETUP_DIR/images/electorates/$x/candidates.txt 
  # SIPL 2011-07-07: Support split groups
  #   See previous comment.
  cat $SETUP_DIR/images.1024/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | awk -F, '{ for (i=1; i<=NF; i++) { if (i == 2) { printf $i-1"," } else if (i==NF) { print $i } else { printf $i"," } } }' > $SETUP_DIR/images.1024/electorates/$x/groups.txt.new
  mv -f $SETUP_DIR/images.1024/electorates/$x/groups.txt.new $SETUP_DIR/images.1024/electorates/$x/groups.txt
  cat $SETUP_DIR/images.1024/electorates/$x/candidates.txt | sed 's/\r//g' | grep -v "^$"  | awk -F, '{ print $1-1","$2","$3-1 }' > $SETUP_DIR/images.1024/electorates/$x/candidates.txt.new 
  mv -f $SETUP_DIR/images.1024/electorates/$x/candidates.txt.new $SETUP_DIR/images.1024/electorates/$x/candidates.txt 
  # SIPL 2011-07-07: Support split groups
  #   See previous comment.
  cat $SETUP_DIR/images.1280/electorates/$x/groups.txt | sed 's/\r//g' | grep -v "^$" | awk -F, '{ for (i=1; i<=NF; i++) { if (i == 2) { printf $i-1"," } else if (i==NF) { print $i } else { printf $i"," } } }' > $SETUP_DIR/images.1280/electorates/$x/groups.txt.new
  mv -f $SETUP_DIR/images.1280/electorates/$x/groups.txt.new $SETUP_DIR/images.1280/electorates/$x/groups.txt
  cat $SETUP_DIR/images.1280/electorates/$x/candidates.txt | sed 's/\r//g' | grep -v "^$"  | awk -F, '{ print $1-1","$2","$3-1 }' > $SETUP_DIR/images.1280/electorates/$x/candidates.txt.new 
  mv -f $SETUP_DIR/images.1280/electorates/$x/candidates.txt.new $SETUP_DIR/images.1280/electorates/$x/candidates.txt 
done


num_languages=`cat $SETUP_DIR/images/messages/languages.txt | sed 's/\r//g' | grep -v "^$" | wc -l`
for (( q = 1 ; $num_languages + 1 - $q ; q++ )) ; do
  mv $SETUP_DIR/images/messages/$q/15.png $SETUP_DIR/images/messages/$q/0.png 
  cd $SETUP_DIR/images/messages/$q/
    for x in `ls heading*png`
    do
      new_name=`echo $x | tr "_" "-"`
      mv $x $new_name
    done
  # "cd -" prints the new directory. We don't need to see it, so redirect it.
  cd - > /dev/null
  mv $SETUP_DIR/images/messages/$q $SETUP_DIR/images/messages/$(($q-1))
done

# 2008-07-14 Display a message saying this takes a long time.
echo "Scaling images for 1024x768.  This can take a long time; please wait . . ."
rm -rf $SETUP_DIR/images.1024/messages/
mkdir $SETUP_DIR/images.1024/messages/
for FILE in `find $SETUP_DIR/images/messages/` ; do
    NEW_FILE=`echo $FILE | sed s/images/images.1024/`
    if [ -d $FILE ] ; then
	mkdir -p $NEW_FILE
    elif echo $FILE | grep -q png\$ ; then
        # 1024 is 88.88% of 1152
	convert -depth 8 -type palette -scale 88.88% $FILE $NEW_FILE
    else
	cp $FILE $NEW_FILE
    fi
done

echo "Scaling images for 1280x1024.  This can take a long time; please wait . . ."
rm -rf $SETUP_DIR/images.1280/messages/
mkdir $SETUP_DIR/images.1280/messages/
for FILE in `find $SETUP_DIR/images/messages/` ; do
    NEW_FILE=`echo $FILE | sed s/images/images.1280/`
    if [ -d $FILE ] ; then
	mkdir -p $NEW_FILE
    elif echo $FILE | grep -q /0.png\$ ; then
        # Special treatment for 0.png (was 15.png, it got
        # renamed to 0.png above).
        # 0.png is full-screen, so it must be scaled
        # both horizontally and vertically. 1280 is 111.11% of 1152;
        # 1024 is 118.5185% of 864
	convert -depth 8 -type palette -scale 111.11%x118.5185% $FILE $NEW_FILE
    elif echo $FILE | grep -q png\$ ; then
        # 1280 is 111.11% of 1152
	convert -depth 8 -type palette -scale 111.11% $FILE $NEW_FILE
    else
	cp $FILE $NEW_FILE
    fi
done


log Storing the image and audio files 
echo Storing the image and audio files, please wait...
rm -f $EVACS_HOME/var/www/html/images
rm -rf $EVACS_HOME/var/www/html/images.1024
rm -rf $EVACS_HOME/var/www/html/images.1152
rm -rf $EVACS_HOME/var/www/html/images.1280
cp -r $SETUP_DIR/images $EVACS_HOME/var/www/html/images.1152
cp -r $SETUP_DIR/images.1024 $EVACS_HOME/var/www/html/images.1024
cp -r $SETUP_DIR/images.1280 $EVACS_HOME/var/www/html/images.1280
cp -r $SETUP_DIR/audio/ $EVACS_HOME/var/www/html/
ln -s $EVACS_HOME/var/www/html/images.1152 $EVACS_HOME/var/www/html/images

log  Updating the eVACS database
echo  Updating the eVACS database, please wait...
echo "COPY party FROM stdin;" > $EVACS_SCRATCH
for electorate in `ls $EVACS_HOME/var/www/html/images/electorates/ | grep -v TRANS`
do
cat $EVACS_HOME/var/www/html/images/electorates/$electorate/groups.txt | sed 's/\r//g' | grep -v "^$" | sed 's/	//g'  | awk -F\, -velectorate=$electorate '{ print electorate"\t"$2"\t"$1"\t"$3"\t"$4}' >> $EVACS_SCRATCH
done
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

echo "COPY candidate FROM stdin;" > $EVACS_SCRATCH
for electorate in `ls $EVACS_HOME/var/www/html/images/electorates/ | grep -v TRANS`
do
    cat $EVACS_HOME/var/www/html/images/electorates/$electorate/candidates.txt | sed 's/\r//g' | grep -v "^$" | sed 's/	//g'  | sed 's/:.*,/,/' | awk -F\, -velectorate=$electorate  '{ print electorate"\t"$1"\t"$3"\t"$2"\tn"}' >> $EVACS_SCRATCH
done
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

# SIPL 2011-07-07: Support split groups
echo "COPY column_splits FROM stdin;" > $EVACS_SCRATCH
for electorate_code in `ls $EVACS_HOME/var/www/html/images/electorates/ | grep -v TRANS`
do
  num_groups_extra_fields=()
  for row in `cat $EVACS_HOME/var/www/html/images/electorates/$electorate_code/groups.txt | sed 's/\r//g' | grep -v "^$" | tr ' ' '_'`
  do
    # Here group_index starts from 0.
    group_index=`echo "$row" | cut -d\, -f2`
    num_fields=`echo "$row" | sed 's/[^,]//g' | wc -m`
    num_groups_extra_fields[$group_index]=$(($num_fields-$num_groups_fields_non_split))
    # num_groups_extra_fields was filled in earlier.
    if [ ${num_groups_extra_fields[$group_index]} -gt 1 ]; then
      # Use "- 1" to ignore the last row.
      for (( physical_column_index = 0 ; $physical_column_index < ${num_groups_extra_fields[$group_index]} - 1; physical_column_index++ ))
      do
        candidate_count=`echo "$row" | cut -d\, -f"$(($num_groups_fields_non_split+$physical_column_index+1))"`
        echo -e "${electorate_code}\t${group_index}\t${physical_column_index}\t${candidate_count}" >> $EVACS_SCRATCH
      done
    fi
  done
done
su postgres -c "psql evacs -f $EVACS_SCRATCH 2>$EVACS_ERRLOG"
checkerror

# Leave the SETUP_DIR intact for troubleshooting later. Just in case!

echo
echo
echo
announce  eVACS Election Data Setup Phase-2 completed successfully! Thank You!
log eVacs Election Data Setup Phase-2 completed successfully!
rm -f $EVACS_ERRLOG $EVACS_SCRATCH 2>/dev/null
eject $CDROM_DEVICE
echo
echo
echo

exit 0
