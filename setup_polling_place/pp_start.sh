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

# This is the start script for the polling place.

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

# SIPL 2011-08-19 Parameters passed to display_first_preferences.
# The values must exactly match those defined in display_first_preferences.h.
PRE_POLL=0
POLLING_DAY=1

bailout()
{
    echo "$@" >&2
    exit 1
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

server_running()
{
    # This sees if anyone is using port 8080 (the master web server port)
    fuser -s -n tcp 8080
}

# SIPL 2011-06-15 The check_barcode() code is now in check_barcode.sh.

# check_barcode()
# {
#    See check_barcode.sh.
# }

get_menu_option()
{
    clear > /dev/tty
    echo "$@" > /dev/tty
    # No longer used.  Now handled by pp_caption.sh.
    # echo "Polling place: $POLLING_PLACE_NAME" > /dev/tty
    echo "Please select one of the following, and press RETURN:" > /dev/tty
    echo > /dev/tty
    echo "1) Display number of votes in electronic ballot box" > /dev/tty
    echo "2) Check if a barcode has been used" > /dev/tty
    if server_running; then
		  echo "3) Stop voting" > /dev/tty
    else
		  echo "4) Start voting" > /dev/tty
		  echo "5) Backup votes" > /dev/tty
		  echo "6) Turn off server" > /dev/tty
                  # SIPL 2011: Display the summary of first preferences of 
                  #            Pre-poll and Polling day separately.
		  echo "7) Display summary of first preferences (pre-poll)" > /dev/tty
		  echo "8) Display summary of first preferences (polling day)" > /dev/tty
		  echo "9) Set the date and time" > /dev/tty
    fi

    read LINE;
    echo "$LINE";
}

# SIPL 2011: Display vote count broken down by pre-poll, polling day,
# post-election.
get_vote_count()
{
    clear > /dev/tty
   
    # SIPL 2011 Use -A option to omit usual header/footer display.
    # SIPL 2014-05-19 Support electorate names with non-alphanumeric characters
    OLDIFS=$IFS
    IFS=$'\n'
    ELECS=`su - postgres -c"psql -A -t evacs <<EOF
SELECT name FROM electorate;
EOF"`
    IFS=$OLDIFS

    # SIPL 2011 Heading for table.  Make sure the format used here
    # matches that used in the printf statement below.
    printf "%20s  %11s  %11s  %13s  %11s\n\n" "" "Pre-Polling" "Polling Day" "Post Election" "Total"

    # An array to hold all vote count information, including
    # Pre-polling, Polling Day, Post Polling Day and Total.
    declare -a vote_counts

    IFS=$'\n'
    for ELECTORATE in $ELECS; do
	ELECTORATE_NORMALIZED=$(normalize_name $ELECTORATE)
        # Run four SQL commands in one "here document".
        vote_counts=(`su - postgres -c"psql -A -t evacs <<EOF
SELECT count(*) FROM ${ELECTORATE_NORMALIZED}_confirmed_vote 
WHERE to_date(time_stamp,'YYYY-MM-DD HH24:MI:SS') < to_date('${ELECTION_DATE}','YYYY-MM-DD');
SELECT count(*) FROM ${ELECTORATE_NORMALIZED}_confirmed_vote 
WHERE to_date(time_stamp,'YYYY-MM-DD HH24:MI:SS') = to_date('${ELECTION_DATE}','YYYY-MM-DD');
SELECT count(*) FROM ${ELECTORATE_NORMALIZED}_confirmed_vote 
WHERE to_date(time_stamp,'YYYY-MM-DD HH24:MI:SS') > to_date('${ELECTION_DATE}','YYYY-MM-DD');
SELECT count(*) FROM ${ELECTORATE_NORMALIZED}_confirmed_vote;
EOF"`)
        printf "%-20s  %11d  %11d  %13d  %11d\n\n" "$ELECTORATE" "${vote_counts[0]}" "${vote_counts[1]}" "${vote_counts[2]}" "${vote_counts[3]}"
    done
    IFS=$OLDIFS
    prompt
}

# SIPL 2011: Display the summary of first preferences of 
#            pre-poll and polling day votes separately.
#            Now, when calling this function, pass in either
#            PRE_POLL or POLLING_DAY as a parameter ($1).
display_firstprefs()
{
	 su postgres -c "$SCRIPTROOT/display_first_preferences \"$ELECTION_DATE\" $1 | less -e -P\"Press space for next page\""
}

backup()
{
	 $SCRIPTROOT/backup.sh
}


httpd_start()
{
	 /etc/rc.d/init.d/httpd start
	 sleep 3
	 /etc/rc.d/init.d/httpd-slave start
	 sleep 3
}


httpd_stop()
{
	 /etc/rc.d/init.d/httpd stop
	 sleep 3
	 /etc/rc.d/init.d/httpd-slave stop
	 sleep 3
}


shutdown()
{
	 /sbin/shutdown -h -t3 now
}


prompt()
{
    echo Press return to return to menu.
    read
}


set_date_time()
{
	# set_date_time changes to the postgres user temporarily, to
	# get access to the database.
	$SCRIPTROOT/set_date_time
}



#
# Script starts here
#

MESSAGE=""

# SIPL 2011: Get election date (TEXT) from database (DD Month YYYY), 
#            and convert it to date format (YYYY-MM-DD).
#            Used for display of ballot counts.
ELECTION_DATE=`su - postgres -c"psql -A -t evacs <<EOF
SELECT to_date(election_date,'DD Month YYYY') FROM master_data ;
EOF"`

# Change into root's home dir, where all the scripts are.
cd $SCRIPTROOT

while true; do
	 # Main menu.
	 case `get_menu_option $MESSAGE` in
		  1) get_vote_count; MESSAGE="";;
		  2) ./check_barcode.sh; MESSAGE="";;
		  3) httpd_stop; MESSAGE="";;
		  4) httpd_start; MESSAGE="";;
		  5) backup; prompt; MESSAGE="";;
		  6) shutdown;;
		  7) display_firstprefs $PRE_POLL; MESSAGE="";;
		  8) display_firstprefs $POLLING_DAY; MESSAGE="";;
		  9) set_date_time; prompt; MESSAGE="";;
		  *) MESSAGE="ERROR: UNKNOWN OPTION SELECTED.";;
	 esac
done
