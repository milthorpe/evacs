# Start script for the election server.

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

# home of executables - "" is equivalent to '/'
export SCRIPTROOT=/opt/eVACS/bin
export EVACS_HOME=/
export EVACS_ERRLOG=/var/log/eVACS_error
export EVACS_SCRATCH=/tmp/eVACS_scratch


# exports: text_mode(MODE FGCOLOUR BGCOLOUR)
#          bailout(msg)
#          announce(msg)
#          instruct(msg)
#          delete_instruction()
source "$SCRIPTROOT/console.sh"

# cdrom.sh exports:
#           $CDROM_DEVICE
#           $CDROM_DIRECTORY
#           $CDROM_SCSI_DEVICE
#           $CDROM_RECORD_OPTIONS
#           load_blank_cdrom()
#
source "$SCRIPTROOT/cdrom.sh" && CDROM='loaded'

# directories we will be using
OUTPUTDIR=/tmp
TEMP_DIRECTORY=/tmp
ISO_DIRECTORY="$TEMP_DIRECTORY"

# CDROM file system switches to mount
MOUNT_OPTIONS=""

# turn off kernel generated messages
dmesg -n1

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

get_menu_option()
{
    clear > /dev/tty1
    echo "$@" > /dev/tty1
    echo "WELCOME TO THE EVACS ELECTION SERVER" > /dev/tty1
    echo "Please select one of the following, and press ENTER:" > /dev/tty1
    echo > /dev/tty1
    echo "1) Run Election Data Setup Phase-1" > /dev/tty1
    echo "2) Generate Barcodes" > /dev/tty1
    echo "3) Backup Database" > /dev/tty1
    echo "4) Restore Database" > /dev/tty1
    echo "5) Run Election Data Setup Phase-2" > /dev/tty1
    echo "6) View Ballot Papers" > /dev/tty1
    echo "7) Set End Of Day Password" > /dev/tty1
    echo "8) Set Date/Time Password" > /dev/tty1
    echo "9) Create Polling Place Server Installation Disk" > /dev/tty1
    echo "10) Create Barcode Image Disk for Printing Contractor" > /dev/tty1
    echo "11) See Election Data Setup Status" > /dev/tty1
    echo "12) Load Electronic Votes From a Polling Place" > /dev/tty1
    echo "13) Load Votes From Scanning" > /dev/tty1
    echo "14) Count Votes For an Electorate" > /dev/tty1
    echo "15) Database Vote Summary" > /dev/tty1
    echo "16) Export Ballots to CD in CSV Format" > /dev/tty1
    echo "17) Export reports, including scrutiny sheets, to CD in TSV format" > /dev/tty1
    echo "18) Run Casual Vacancy" > /dev/tty1
    echo "E) Eject CD-ROM" > /dev/tty1
    echo "P) Clear Printer Queue" > /dev/tty1
    echo "0) Shutdown Election Server" > /dev/tty1
    read LINE;
    echo "$LINE";
    clear > /dev/tty1
}


prompt()
{
    echo Press ENTER to return to menu.
    read
}


get_dump_option()
{
    clear > /dev/tty1
    echo "$@" > /dev/tty1
    echo "Please select one of the following, and press ENTER:" > /dev/tty1
    echo > /dev/tty1
    echo "1) Export 'raw' Data-Entered papers (unnormalised)" > /dev/tty1
    echo "2) Export counting database (normalised confirmed votes)" > /dev/tty1
    echo "3) Export ALL (options 1 & 2)" > /dev/tty1
    echo "4) Return to main menu" > /dev/tty1
    read LINE;
    echo "$LINE";
}

get_electorate_code()
{
    clear > /dev/tty1
    echo "$@" > /dev/tty1
    echo "Please select one of the following, and press ENTER:" > /dev/tty1
    echo > /dev/tty1
    # SIPL 2014-05-19 Support electorate names with non-alphanumeric characters
    OLDIFS=$IFS
    IFS=$'\n'
    for ELECTORATE in `cat /var/www/html/images/electorates.txt` ; do
	CODE=`echo $ELECTORATE | cut -f1 -d,`
	NAME=`echo $ELECTORATE | cut -f2 -d,`
	echo "${CODE}) View Ballot Paper for ${NAME}" > /dev/tty1
    done
    IFS=$OLDIFS
    echo "Enter any other key to return to main menu" > /dev/tty1
    read LINE;
    echo -n "$LINE";
}

get_ballot_type()
{
    echo "" >  /dev/tty1
    echo "Please select a resolution, and press ENTER:" > /dev/tty1
    echo > /dev/tty1
    echo "1) View Ballot Paper for PC (1152x864 resolution)" > /dev/tty1
    echo "2) View Ballot Paper for Voting Machine (1024x768 resolution)" > /dev/tty1
    echo "3) View Ballot Paper for New PC (1280x1024 resolution)" > /dev/tty1
    read LINE;
    echo "$LINE";
}

show_ballots()
{
    # X11 programs are now in /usr/bin.
    # PATH=$PATH:/usr/X11R6/bin/
    CONTINUE="true"


    if [ ! -f /var/www/html/images/electorates.txt ]; then
		  CONTINUE="false"
        echo "Cannot find /var/www/html/images/electorates.txt file - Please Run Setup Phases 1 & 2 first"	
    fi

    # loop until CONTINUE is "false"
    while  [ $CONTINUE == "true" ]   ; do
	code=`get_electorate_code`
	if ! cat /var/www/html/images/electorates.txt | cut -f1 -d, | grep -q "^${code}\$"; then
	    CONTINUE="false"
	fi
	if [ $CONTINUE == "true" ] ; then
	    electorate=`head -${code} /var/www/html/images/electorates.txt | tail -1 | cut -f2 -d,`
	    seats=`head -${code} /var/www/html/images/electorates.txt | tail -1 | cut -f3 -d,`
	    TYPE=`get_ballot_type`
		#read TYPE
	    # SIPL 2014-05-19 Removed electorate name parameter to
	    #                 voting_client.sh/voting_client_stripped_bin.
	    case $TYPE in
		1)  rm -f /var/www/html/images
		    ln -s /var/www/html/images.1152 /var/www/html/images
		    # sed -i 's/^\(.*\)Modes.*$/\1Modes    "1152x864"/' /etc/X11/XF86Config
		    /usr/bin/xinit -e /bin/su postgres -c"$SCRIPTROOT/voting_client.sh $code $seats 1152 864" &> /dev/null;;
		2)  rm -f /var/www/html/images
		    ln -s /var/www/html/images.1024 /var/www/html/images
		    # sed -i 's/^\(.*\)Modes.*$/\1Modes    "1024x768"/' /etc/X11/XF86Config
		    /usr/bin/xinit -e /bin/su postgres -c"$SCRIPTROOT/voting_client.sh $code $seats 1024 768" &> /dev/null;;
		3)  rm -f /var/www/html/images
		    ln -s /var/www/html/images.1280 /var/www/html/images
		    # sed -i 's/^\(.*\)Modes.*$/\1Modes    "1280x1024"/' /etc/X11/XF86Config
		    /usr/bin/xinit -e /bin/su postgres -c"$SCRIPTROOT/voting_client.sh $code $seats 1280 1024" &> /dev/null;;
		*) echo "ERROR: UNKNOWN OPTION SELECTED.";;
	    esac
	fi
    done
}

run_hare_clark()
{
    # remove any previous output files before proceeding
    rm -f $OUTPUTDIR/table1.ps
    rm -f $OUTPUTDIR/table2.ps
    rm -f $OUTPUTDIR/raw

    # SIPL 2014-03-25 Increase stack limit to accommodate electorates
    # with nine seats.
    su postgres -c "ulimit -s 16384; $SCRIPTROOT/hare_clark" > /dev/tty1
    if [ $? != 0 ]; then
        # Sleep 5 so that the error message can be seen
        sleep 5
        bailout "Hare Clark failed. Aborting ...."
    fi

    # table4 - First preference votes by polling place

#    su postgres -c "$SCRIPTROOT/report_preferences_by_polling_place" > /dev/tty1
#    if [ $? != 0 ]; then
#        bailout "Report: 'First preference votes by polling place' failed. Aborting ...."
#    fi

    $SCRIPTROOT/print_scrutiny.sh
}

run_casual_vacancy()
{
    # remove any previous output files before proceeding
    rm -f $OUTPUTDIR/table1.ps
    rm -f $OUTPUTDIR/table2.ps
    rm -f $OUTPUTDIR/raw
    # SIPL 2014-03-25 Increase stack limit to accommodate electorates
    # with nine seats.
    su - postgres -c "ulimit -s 16384; $SCRIPTROOT/vacancy" > /dev/tty1 && echo 0
    if [ $? != 0 ]; then
	announce "Casual Vacancy failed."
    fi

    # NOTE: Casual vacancy calls print_scrutiny in-line
    # so that it can loop and do another vacancy on the same electorates'
    # ballots


    # table4 - First preference votes by polling place
    # The table4s postscript files are not printed.

#    su postgres -c "$SCRIPTROOT/report_preferences_by_polling_place" > /dev/tty1
#    if [ $? != 0 ]; then
#        announce "Report: 'First preference votes by polling place' failed."
#    fi

}

dump_ballots()
{
    QUIT=""
    MESSAGE="Export to CDROM: Please enter your choice"
    # loop until message is NULL
    while  [ -n "$MESSAGE" ]   ; do
		  OPTION=`get_dump_option $MESSAGE`
		  # SIPL 2011-09-06 Ensure RETURN_CODE is always set,
		  # so that the subsequent test will not unnecessarily
		  # fail.
		  RETURN_CODE=0
		  case $OPTION in
				1) CDPATH=/tmp/evacs_export/paper_ballots; VOL="BLT" ;MESSAGE="";
					 RETURN_CODE=`su - postgres -c"$SCRIPTROOT/export_ballots && echo 0"`;;
				2) CDPATH=/tmp/evacs_export/confirmed_votes; VOL="VOT"; MESSAGE="";
					 RETURN_CODE=`su - postgres -c"$SCRIPTROOT/export_confirmed && echo 0"`;;
            3) 	CDPATH=/tmp/evacs_export; VOL="ALL";MESSAGE="";
					 RETURN_CODE=`su - postgres -c"$SCRIPTROOT/export_confirmed && $SCRIPTROOT/export_ballots && echo 0"`;;
				4) MESSAGE=""; QUIT=1;;
				*) MESSAGE="ERROR: UNKNOWN OPTION SELECTED.";;
		  esac
    done

    # check for an execution error in the dump program
    if [ "$RETURN_CODE" != 0 ]; then
		  bailout "Export ($VOL) failed. Aborting ...."
    fi

    # process newly generated ballot export
    if [ -z "$QUIT" ] ;then
		  # change to output directory
		  cd $OUTPUTDIR

		  # SIPL 2011-06-15 Moved this here from above, so that
		  # the timestamp is now, not when this script first started.
		  # create file name for export image
		  DATE=`date +%Y%m%d%H%M`
		  ISO_IMAGE=`echo EXPORT-$DATE.iso | sed "s/ /_/g"`

		  # Create an ISO image of the directory containing the export files
		  VOLUME_NAME=`echo "$VOL-$DATE"`
		  announce "Making disk image ($ISO_IMAGE)"
		  mkisofs --quiet -r -J -V $VOLUME_NAME  -o $TEMP_DIRECTORY/$ISO_IMAGE "$CDPATH"  2>&1 > /dev/null
		  if [ $? != 0 ]; then
            # DDSv1D-3.2: Format Backup Error Message
				bailout "Export ($VOL) failed during disk image creation phase."
		  fi

		  #prompt the user to load a blank CD if there is not already one loaded
		  load_blank_cdrom "Please insert a blank CD and press ENTER."

		  # Record the iso image to the loaded blank CDROM
		  announce "writing to CD ($CDROM_DEVICE)"
		  # SIPL 2011-08-22 Fedora 14 uses wodim, not cdrecord.
		  # cdrecord  dev=$CDROM_SCSI_DEVICE $CDROM_RECORD_OPTIONS "$TEMP_DIRECTORY/$ISO_IMAGE" 2>&1 > /dev/null
		  wodim dev=$CDROM_DEVICE $CDROM_RECORD_OPTIONS "$TEMP_DIRECTORY/$ISO_IMAGE" 2>&1 > /dev/null
		  if [ $? != 0 ]; then
            # DDSv1D-3.2: Format Backup Error Message
				bailout  "Export ($VOL) failed during CD record phase."
		  fi
	
		  # cleanup
		  rm -rf $TEMP_DIRECTORY/$ISO_IMAGE
		  announce "Thankyou. Exporting $VOL to CDROM complete."
		  eject $CDROM_DEVICE
    fi
    # change back to script directory
    cd $SCRIPTROOT
}

set_pp_passwd()
{
    oldmodes=`stty -g`
    stty -echo
    su postgres -c "$SCRIPTROOT/set_polling_place_password"
    stty $oldmodes
    prompt
}

set_date_time_passwd()
{
    oldmodes=`stty -g`
    stty -echo
    su postgres -c "$SCRIPTROOT/set_date_time_password"
    stty $oldmodes
    prompt
}

tsv_to_cd()
{
    announce "Copying scrutiny sheets to CD in TSV format."

    su postgres -c "$SCRIPTROOT/report_preferences_by_polling_place" > /dev/tty1
    if [ $? != 0 ]; then
        bailout "Report: 'First preference votes by polling place' failed. Aborting ...."
    fi

    TSVCDTMPDIR=/tmp/tsvcd/
    ISO_FILE=/tmp/scrutiny.iso

#create temporary directory
    if [ ! -d $TSVCDTMPDIR ] ; then
	mkdir $TSVCDTMPDIR
	if [ ! -d $TSVCDTMPDIR ] ; then
	    bailout "Unable to create temporary directory "$TSVCDTMPDIR"."
	fi
    fi

    NUM_ELECS=`su - postgres -c"psql evacs <<EOF
SELECT COUNT(*) from electorate;
EOF"| sed 's/^ *//g' | tail -3 | head -1`
 
    OLDIFS=$IFS
    IFS=$'\n'
    ELECS=`su - postgres -c"psql evacs <<EOF
SELECT name from electorate;
EOF"| sed 's/^ *//g' | tail -"$(($NUM_ELECS+2))" | head -"$NUM_ELECS"`

    for ELECTORATERAW in $ELECS; do
	ELECTORATE=$(normalize_name ${ELECTORATERAW})
#check existance of tsv files & move to temporary directory
	TABLE1="/tmp/table1."$ELECTORATE".dat"
	TABLE2="/tmp/table2."$ELECTORATE".dat"
	TABLE4="/tmp/table4."$ELECTORATE".dat"
	# 2014-02-07 Also support PostScript version of Table 4
	TABLE4PS="/tmp/table4."$ELECTORATE".ps"
	TABLE1OUT=$TSVCDTMPDIR"/table1."$ELECTORATE".tsv"
	TABLE2OUT=$TSVCDTMPDIR"/table2."$ELECTORATE".tsv"
	TABLE4OUT=$TSVCDTMPDIR"/table4."$ELECTORATE".tsv"
	TABLE4PSOUT=$TSVCDTMPDIR"/table4."$ELECTORATE".ps"
	if [ -r $TABLE1 ] && [ -r $TABLE2 ] ; then
	    $SCRIPTROOT/filter_dat.pl $TABLE1 $TABLE1OUT $TABLE2 $TABLE2OUT
	    # strips any carriage returns from the files.
	    # this occurs with the 2001 election data, see TIR 30
	    sed -i "s///g" $TABLE1OUT $TABLE2OUT
	fi
	if [ -r $TABLE4 ] ; then
	    $SCRIPTROOT/filter_table4_dat.pl $TABLE4 $TABLE4OUT
	    # 2014-02-07 Also copy PostScript version of Table 4
	    cp $TABLE4PS $TABLE4PSOUT
        fi
    done
    IFS=$OLDIFS
#prompt user
    echo
    echo The following files will be copied to the CD:
    echo
    ls $TSVCDTMPDIR
    echo
    echo Press Y to continue, any other key to abort
    read answer
    echo
    if [[ "$answer" == "Y" || "$answer" == "y" ]] ; then
#create iso
	/usr/bin/mkisofs -r -f -J -T -v -V "SCRUTINY`date +%D`" -o $ISO_FILE $TSVCDTMPDIR 2>&1 > /dev/null
	if [ $? != 0 ] ; then
	    bailout "Errors creating CD image"
	fi
#burn to cd
	load_blank_cdrom "Please insert a blank CD and press ENTER."
	# SIPL 2011-08-22 Fedora 14 uses wodim, not cdrecord.
	# cdrecord dev=$CDROM_SCSI_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_FILE 2>&1 > /dev/null
	wodim dev=$CDROM_DEVICE $CDROM_RECORD_OPTIONS -data $ISO_FILE 2>&1 > /dev/null
    else
	bailout Scrutiny CD creation aborted at user request
    fi
#cleanup
    rm -f $ISO_FILE
    rm -rf $TSVCDTMPDIR
    announce "Thankyou. Exporting scrutiny sheets to CD complete."
}

display_summary()
{
    NUM_ELECS=`su - postgres -c"psql evacs <<EOF
SELECT COUNT(*) from electorate;
EOF"| sed 's/^ *//g' | tail -3 | head -1`

    ELECS=`su - postgres -c"psql evacs <<EOF
SELECT name from electorate;
EOF"| sed 's/^ *//g' | tail -"$(($NUM_ELECS+2))" | head -"$NUM_ELECS"`

    echo Confirmed Votes:

    # SIPL 2014-05-19 Support electorate names with non-alphanumeric characters
    OLDIFS=$IFS
    IFS=$'\n'
    for ELECTORATE in $ELECS; do

	ELECTORATE_QUOTED=${ELECTORATE//\'/\'\'}
	ELECTORATE_NORMALIZED=$(normalize_name $ELECTORATE)

        CODE=`su - postgres -c"psql evacs <<EOF
SELECT code FROM electorate WHERE name='$ELECTORATE_QUOTED';
EOF" |  sed 's/^ *//g' | tail -3 | head -1`
        INF_IX=`echo "$CODE * 2" | bc`
	echo -n "$CODE          $ELECTORATE Total: "

        VOTES[$CODE]=`su - postgres -c"psql evacs <<EOF
SET client_min_messages=WARNING;
SELECT COUNT(*) FROM ${ELECTORATE_NORMALIZED}_confirmed_vote;
EOF" | sed 's/^ *//g' | tail -3 | head -1`
	echo -n "${VOTES[$CODE]} Informal: "

	VOTES[$INF_IX]=`su - postgres -c"psql evacs <<EOF
SET client_min_messages=WARNING;
SELECT COUNT(*) FROM ${ELECTORATE_NORMALIZED}_confirmed_vote WHERE preference_list='';
EOF" | sed 's/^ *//g' | tail -3 | head -1`
	echo "${VOTES[$INF_IX]}"
    done
    IFS=$OLDIFS
}

#
# Script starts here
#

# Change into root's home dir, where all the scripts are.
cd $SCRIPTROOT

while true; do

# Main menu.
     case `get_menu_option $MESSAGE` in
	1) $SCRIPTROOT/setup_phase1.sh; prompt; MESSAGE="";;
	2) $SCRIPTROOT/generate_barcodes.sh; prompt; MESSAGE="";;
	3) $SCRIPTROOT/backup_DB.sh; prompt; MESSAGE="";;
	4) $SCRIPTROOT/restore_DB.sh; prompt; MESSAGE="";;
	5) $SCRIPTROOT/setup_phase2.sh; prompt; MESSAGE="";;
	6) show_ballots; sleep 1; setfont default8x16; setsysfont; prompt; MESSAGE="";;
	7) set_pp_passwd; MESSAGE="";;
	8) set_date_time_passwd; MESSAGE="";;
	9) $SCRIPTROOT/create_PP.sh; prompt; MESSAGE="";;
	10) $SCRIPTROOT/make_barcode_cd.sh; prompt; MESSAGE="";;
	11) $SCRIPTROOT/show_setup_status.sh; prompt; MESSAGE="";;
	12) $SCRIPTROOT/load_votes.sh; prompt; MESSAGE="";;
	13) $SCRIPTROOT/load_scanned_votes.sh; prompt; MESSAGE="";;
	14) run_hare_clark; prompt; MESSAGE="";;
	15) display_summary; prompt; MESSAGE="";;
	16) dump_ballots; prompt; MESSAGE="";;
	17) tsv_to_cd; prompt; MESSAGE="";;
	18) run_casual_vacancy; prompt; MESSAGE="";;
	E) eject; MESSAGE="";;
	P) lprm -; MESSAGE="";;
	0) shutdown -h now;;
	*) MESSAGE="ERROR: UNKNOWN OPTION SELECTED.";;
     esac
done
















