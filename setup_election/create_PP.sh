#! /bin/sh
# Script to create the polling place server CD
#-----------------------------------------------
#

# All constants for this file are defined up here.
BASE_DIR=/opt/eVACS
VER=`rpm -q --qf %{VERSION} evacs-election-server`       # Determine the current eVACS version and releae
REL=`rpm -q --qf %{RELEASE} evacs-election-server`       # and release
RPM_TOPDIR="$BASE_DIR/rpm"
ARCH=`arch`
SRC_DIR="$BASE_DIR/src"
ISO_DIR="$BASE_DIR/evacs-voting-server-$VER-$REL/"       # directory where the ISO file will be created
ISO_IMG="$BASE_DIR/evacs-voting-server-$VER-$REL.iso"
DB_FILE="$SRC_DIR/evacs.pgdump"

ISOFS_OPTIONS='-uid 0 -gid 0 -R -f -J -T -v -V \"eVACS_Voting_Server\" -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table'

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

# SIPL 2014-05-20
# Utility function to replace non-alphanumeric characters with underscores.
# This is applied to electorate names. E.g., this will convert
#  "A name with spaces and a hy-phen and an A'postrophe"
# into:
#  "A_name_with_spaces_and_a_hy_phen_and_an_A_postrophe"
normalize_name()
{
    echo -n "$@" | tr -c '[A-Za-z0-9]' _
}

get_polling_place_type()
{
    echo "" >  /dev/tty1
    echo "Please select a polling place type, and press ENTER:" > /dev/tty1
    echo > /dev/tty1
    echo "1) PC voting clients (1152x864 resolution)" > /dev/tty1
    echo "2) Voting Machine voting clients (1024x768 resolution)" > /dev/tty1
    echo "3) New PC voting clients (1280x1024 resolution)" > /dev/tty1
    read LINE;
    echo "$LINE";
}

#
# Script starts here
#


if [[ -z $VER || -z $REL ]] ; then
	 bailout "eVACS isn't installed. You need to reinstall the election server";
fi

# check if the voting server base has been loaded
if [ ! -d $ISO_DIR ] ; then
	 load_evacs_cdrom "Please load the eVACS voting server base CD"

	 if [[ ! -f "$CDROM_DIRECTORY/eVACS-voting-server-$VER-$REL.spec" && ! -f "$CDROM_DIRECTORY/evacs-voting-server.tgz" ]] ; then
		  eject
		  bailout "Not a valid eVACS voting server base CD"
	 fi

	 announce "Loading image from CD, please wait ..."
	
	mkdir $ISO_DIR
	mkdir $SRC_DIR
        mkdir $RPM_TOPDIR
        mkdir $RPM_TOPDIR/BUILD $RPM_TOPDIR/SOURCES \
          $RPM_TOPDIR/SPECS $RPM_TOPDIR/SRPMS


	 if `cp -r $CDROM_DIRECTORY/* $ISO_DIR` && `cp $CDROM_DIRECTORY/.discinfo $ISO_DIR` && `mv $ISO_DIR/evacs-voting-server-$VER-$REL.spec $RPM_TOPDIR/SPECS` && `mv $ISO_DIR/evacs-voting-server.tgz $SRC_DIR` ; then
		  announce "done."
		  eject
	 else
                  rm -fr $ISO_DIR
		  bailout "Loading image failed - please try again!"
		  eject
	 fi

	 cd $SRC_DIR
	 tar zxvvf evacs-voting-server.tgz
	 if [ $? != 0 ] ; then
		  bailout "No space left on device - you need a larger hard drive"
	 fi
fi

# check if the variable data has been loaded 
rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(*) from candidate;
EOF" | cut -d'(' -f1`
b_rows=`echo $rows | sed 's/count ------- //g'`
if [ $b_rows -eq 0 ]; then
	 bailout "Please run Election Data Setup first!"
fi

# check if an end-of-day password hash has been loaded
rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(password_hash) from master_data;
EOF" | sed -n 3p | tr -d " "`
if [ $rows -eq 0 ]; then
	 bailout "Please set end of day password first!"
fi

# check if a date/time password hash has been loaded
rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(password_hash_date_time) from master_data;
EOF" | sed -n 3p | tr -d " "`
if [ $rows -eq 0 ]; then
	 bailout "Please set date/time password first!"
fi

echo "Create Polling Place CD"
echo
echo "Enter the name of the Polling Place for which the CD is to be created" 
read  name
code=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select code from polling_place where name='$name';
EOF" | cut -d"(" -f1 | tr -d '-' `
pp_code=`echo "$code" | tr -d '\n' | awk '{print $2}' `
if [ "x$pp_code" == "x" ]; then
  echo "$name: No Such Polling Place. Please check spelling, spaces, and capitalisation" 
  echo "Press Y for the list of Valid Polling Places, any other key to exit" 
  read ans
  if [[ "x$ans" == "xY" || "x$ans" == "xy" ]]; then
    # SIPL 2011-08-30 Don't display pre-poll place names.
    # SIPL 2011-11-24 Remove extraneous space after EOF, add -A -t options,
    #                 add blank lines around the output.
    # SIPL 2011-11-28 Rewrite the query to include polling places
    #                 that do not have a corresponding pre-poll code, and
    #                 to sort the results alphabetically.
    echo
    su postgres -c "psql -A -t evacs 2>/dev/null <<EOF
    select name from polling_place pp1 where not exists
      (select * from polling_place pp2 where pp1.code = pp2.pre_polling_code)
      order by name;
EOF" | sort | more
    echo
  fi
  exit -1
fi

# SIPL 2011-08-30 New check: is it a pre-poll name?
#   Find if there is a polling place for which $pp_code
#   is the pre-polling polling place code.
is_pre_poll_code=`su postgres -c "psql -A -t evacs 2>/dev/null <<EOF
  select code from polling_place where pre_polling_code=$pp_code;
EOF"`
if [ "x$is_pre_poll_code" != "x" ]; then
  echo "$name: You can't create a polling place CD only for pre-polling."
  echo "You must enter the polling place name without the pre-polling indicator." 
  echo "Press Y for the list of Valid Polling Places, any other key to exit" 
  read ans
  if [[ "x$ans" == "xY" || "x$ans" == "xy" ]]; then
    # SIPL 2011-08-30 Don't display pre-poll place names.
    # SIPL 2011-11-24 Remove extraneous space after EOF, add -A -t options
    #                 add blank lines around the output.
    # SIPL 2011-11-28 Rewrite the query to include polling places
    #                 that do not have a corresponding pre-poll code, and
    #                 to sort the results alphabetically.
    echo
    su postgres -c "psql -A -t evacs 2>/dev/null <<EOF
    select name from polling_place pp1 where not exists
      (select * from polling_place pp2 where pp1.code = pp2.pre_polling_code)
      order by name;
EOF" | sort | more
    echo
  fi
  exit -1
fi

# SIPL 2011-08-30 Tell the user whether or not pre-polling
#   will be supported.
# SIPL 2011-11-28 Reworded to make clearer.
echo
pre_poll_code=`su postgres -c "psql -A -t evacs 2>/dev/null <<EOF
  select pre_polling_code from polling_place where code=$pp_code;
EOF"`
if [ "$pre_poll_code" == "-1" ]; then
  echo "Ballots WILL NOT be moved into separate pre-polling and"
  echo "polling day batches during import."
else
  echo "Ballots WILL be moved into separate pre-polling and"
  echo "polling day batches during import."
fi
echo



#check if this polling place has been barcoded  
rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(*) from barcode where polling_place_code=$pp_code;
EOF" | cut -d'(' -f1`
count=`echo $rows | sed 's/count ------- //g'`
if [ $count -eq 0 ]; then
	 bailout "No barcodes have been allocated for $name!"
fi


#check if votes already exist in the database
# SIPL 2014-05-20 Support electorate names with non-alphanumeric characters
OLDIFS=$IFS
IFS=$'\n'
for electorateraw in `cut -f2 -d, /var/www/html/data/electorate_details` ;
  do
  # SIPL 2014-05-20 Have to reset/set IFS inside the loop
  #                 so as not to break the assignments to $rows
  IFS=$OLDIFS
  electorate=$(normalize_name "${electorateraw}")

  rows=`echo "SELECT COUNT(*) FROM "$electorate"_confirmed_vote" | su postgres -c "psql evacs 2>/dev/null" | cut -d'(' -f1 `
  count=`echo $rows | sed 's/count ------- //g'`
  if [ $count -ne 0 ]; then
      bailout "Votes already exist in the database! Cannot create polling place server disc."
  fi
  rows=`echo "SELECT COUNT(*) FROM "$electorate"_entry" | su postgres -c "psql evacs 2>/dev/null" | cut -d'(' -f1 `
  count=`echo $rows | sed 's/count ------- //g'`
  if [ $count -ne 0 ]; then
      bailout "Votes already exist in the database! Cannot create polling place server disc."
  fi
  rows=`echo "SELECT COUNT(*) FROM "$electorate"_paper" | su postgres -c "psql evacs 2>/dev/null" | cut -d'(' -f1 `
  count=`echo $rows | sed 's/count ------- //g'`
  if [ $count -ne 0 ]; then
      bailout "Votes already exist in the database! Cannot create polling place server disc."
  fi
  IFS=$'\n'
done
IFS=$OLDIFS

#get polling place type
TYPE=`get_polling_place_type`
case $TYPE in
    1)  rm -f /var/www/html/images
	ln -s /var/www/html/images.1152 /var/www/html/images
        rm -f /var/www/html/resolution.txt
        echo "1152 864" > /var/www/html/resolution.txt;;
    2)  rm -f /var/www/html/images
	ln -s /var/www/html/images.1024 /var/www/html/images
        rm -f /var/www/html/resolution.txt
        echo "1024 768" > /var/www/html/resolution.txt;;
    3)  rm -f /var/www/html/images
	ln -s /var/www/html/images.1280 /var/www/html/images
        rm -f /var/www/html/resolution.txt
        echo "1280 1024" > /var/www/html/resolution.txt;;
    *) bailout "ERROR: Unknown polling place type.";;
esac

echo Updating database, please wait...  
su postgres -c "psql evacs 2>/dev/null <<EOF
delete from server_parameter;
insert into server_parameter values (1,$pp_code);
EOF"


echo Extracting database, please wait... 
if [ ! -f $EVACS_ERRLOG ] ; then
	touch $EVACS_ERRLOG;
fi
chmod 666 $EVACS_ERRLOG;
su postgres -c "pg_dump evacs -x -f /tmp/evacs.pgdump 2> $EVACS_ERRLOG"
checkerror
mv /tmp/evacs.pgdump $DB_FILE

# Create initial cursor sequences.
# SIPL 2014-05-20 Support electorate names with non-alphanumeric characters
OLDIFS=$IFS
IFS=$'\n'
for ELECTORATE in `cut -f1-2 -d, /var/www/html/data/electorate_details` ;
do
  CODE=`echo $ELECTORATE | cut -f1 -d,`
  NAME=$(normalize_name `echo $ELECTORATE | cut -f2 -d,`)
  NUM_GROUPS=`su - postgres -c"psql evacs <<EOF
SELECT COUNT(*) from party WHERE electorate_code=$CODE;
EOF"| sed 's/^ *//g' | tail -3 | head -1`

echo >> $DB_FILE
echo CREATE SEQUENCE "$NAME"_cursor_seq START 0 MINVALUE 0 MAXVALUE $(($NUM_GROUPS - 1)) CYCLE\; >> $DB_FILE
echo >> $DB_FILE

done
IFS=$OLDIFS

# SIPL 2014-03-24 Support electorates with nine seats.
# SIPL 2014-05-21 The previous change broke this. Now do the grants for
#                 robson_rotation_9 and robson_9_seq separately,
#                 as they may not exist.
#                 (Currently, robson_rotation_9 will always exist,
#                 but robson_9_seq will only exist if there's an electorate
#                 with nine seats.)
#                 The failure of an individual GRANT does not cause
#                 the whole script to fail, so if robson_9_seq does
#                 not exist, there will be an error on the console,
#                 but the other GRANTs will not be not affected.
# Grant apache (cgi-bin apps) access to database entities
cat >> $DB_FILE <<EOF
CREATE USER apache NOCREATEDB NOCREATEUSER;

GRANT ALL ON TABLE barcode, batch, batch_history, candidate, column_splits, duplicate_entries, electorate, master_data, party, polling_place, preference_summary, robson_rotation_5, robson_rotation_7, scrutiny, scrutiny_pref, server_parameter, vote_summary TO apache;

GRANT ALL ON TABLE robson_rotation_9 TO apache;

GRANT ALL ON batch_history_id_seq, duplicate_entries_id_seq, robson_5_seq, robson_7_seq TO apache;

GRANT ALL ON robson_9_seq TO apache;
EOF

# SIPL 2014-05-20 Support electorate names with non-alphanumeric characters
OLDIFS=$IFS
IFS=$'\n'
for ELECTORATE in `cat /var/www/html/images/electorates.txt` ; do
    NAME=$(normalize_name `echo $ELECTORATE | cut -f2 -d,`)
    echo GRANT ALL ON TABLE ${NAME}_confirmed_vote, ${NAME}_entry, ${NAME}_paper TO apache\; >> $DB_FILE
    echo GRANT ALL ON ${NAME}_confirmed_id_seq, ${NAME}_cursor_seq, ${NAME}_entry_id_seq, ${NAME}_paper_id_seq TO apache\; >> $DB_FILE
done
IFS=$OLDIFS

echo Organising required files, please wait... 
mkdir -p $SRC_DIR/evacs-voting-server-$VER/data/
mv $DB_FILE $SRC_DIR/evacs-voting-server-$VER/data/
cd /var/www/html
tar zcvvf $SRC_DIR/evacs-voting-server-$VER/data/html_data.tgz . > /dev/null 2>&1
cd $SRC_DIR
tar czf $RPM_TOPDIR/SOURCES/evacs-voting-server.tgz evacs-voting-server-$VER >> $EVACS_ERRLOG 2>&1
cd $OLDPWD

#
# Build the RPM - run through %prep and %install only
#
echo "Building the RPM, this may take a while ..."
/usr/bin/rpmbuild -ba --define "_topdir $RPM_TOPDIR" \
  --define 'debug_package %{nil}' \
  $RPM_TOPDIR/SPECS/evacs-voting-server-$VER-$REL.spec >> $EVACS_ERRLOG 2>&1 
if [ $? != 0 ] ; then
	 bailout "Failed to build RPM - try again?"
fi

mv $RPM_TOPDIR/RPMS/$ARCH/evacs-voting-server-$VER-$REL.$ARCH.rpm $ISO_DIR/Packages/
if [ $? != 0 ] ; then
	 bailout "Failed to copy RPM - try again?"
fi

#
# Update Fedora installer
#
echo "Updating the Fedora installer"
# Generate yum repository (repodata directory)
rm -rf $ISO_DIR/repodata
createrepo -g comps.xml -d --unique-md-filenames \
  -u "media://$(head -1 $ISO_DIR/.discinfo)" \
  -o $ISO_DIR \
  $ISO_DIR
if [ $? != 0 ] ; then
	 bailout "Failed to create yum repository - try again?"
fi

# Make .treeinfo
sed -e "s/REPOMDXMLSHA/`sha256sum $ISO_DIR/repodata/repomd.xml |
  cut -d\  -f 1`/" \
  < $ISO_DIR/treeinfo-template.txt > $ISO_DIR/.treeinfo
if [ $? != 0 ] ; then
	 bailout "Failed to create .treeinfo - try again?"
fi

announce "Making ISO image for Polling Place CD, please wait..."
cd $ISO_DIR
mkisofs $ISOFS_OPTIONS -o $ISO_IMG . > $EVACS_ERRLOG 2>&1
if [ $? != 0 ]; then
	 bailout "Could not generate ISO image!" 
fi
# "cd -" prints the new directory. We don't need to see it, so redirect it.
cd - > /dev/null

# SIPL 2011-08-01 The instruction was:
#  "Please insert a blank CD-R or CD-RW for the Polling Place CD for $name"
# but DVDs are allowed too.
load_blank_cdrom "Please insert a blank disk for the Polling Place CD for $name"
announce "Writing image to CD, please wait..."

# SIPL 2011-07-28 Fedora 14 uses wodim, not cdrecord.
#cdrecord dev=$CDROM_SCSI_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_IMG
wodim dev=$CDROM_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_IMG
if [ $? != 0 ]; then
	 bailout "Could not Write to CD!"
fi


echo
echo
echo
rm -f $EVACS_ERRLOG
eject $CDROM_DEVICE
warn  "This CD is the Polling Place Server for $name. Please label the CD appropriately"
echo "Thank You!"
echo
echo
echo
exit 0
