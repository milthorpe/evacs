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

export BARCODES_DIR=/tmp/barcodes

echo                                                                                                                                                             
echo                                                                                                                                                             
echo                                                                                                                                                             
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
                                                                                                                                                             

if [ -z $EVACS_HOME ]; then
  bailout "Please set the environment variable EVACS_HOME before proceeding"
fi

# SIPL 2011-09-15 Create the error log file and allow write access,
#   so that the subsequent output redirection succeeds.
touch $EVACS_ERRLOG
chmod 666 $EVACS_ERRLOG

#date=`su postgres -c "psql evacs 2>/dev/null <<EOF
#  select election_date from master_data;
#EOF" | cut -d\( -f1 `
#
#if [ -z $date 2>/dev/null ]; then
#  year="not available"
#  yy="00"
#else
#  year=`echo $date | awk '{print $NF}'`
#  yy=`echo $year | cut -c 3,4`
#fi
#
#echo
#echo "********************************************************************"
#echo "You can embed any two alphabets or digits into the Barcode to minimise"
#echo "the possibility of the same barcode being generated for the next elections."
#echo "It is recommended that you embed the the 2-digit year into the barcode."
#echo "********************************************************************"
#echo
#echo "Do you want to embed the Election Year in the Barcodes (Y/N)"?
#read ans
#if [[ "$ans" == "Y" || "$ans" == "y" ]] ; then
#  echo "Election Year is $year. Generate Barcodes with embedded year $yy?"
#  read ans2
#  if [[ "$ans2" == "Y" || "$ans2" == "y" ]] ; then
#    export ELECTION_YEAR=$yy
#  else
#    while true
#    do
#      echo "Enter the 2-digit year e.g. for 2004, enter 04."
#      read yy
#      if [ `echo $yy | wc -c` -eq 3 ]; then
#         export ELECTION_YEAR=$yy
#         break;
#      fi
#      echo "\"$yy\" is invalid"
#    done  
#  fi
#  echo Generating Barcodes with embedded election year \"$yy\" in 10 seconds.
#  echo Press Control-C NOW to if you want to cancel. 
#else
#  echo Generating Barcodes WITHOUT embedded election year in 10 seconds.
#  echo Press Control-C NOW to if you want to cancel. 
#fi
#
#sleep 5
#echo
#echo Generating Barcodes in 5 seconds.
#echo Press Control-C NOW to if you want to cancel. 
#echo
#sleep 5

#check if the barcodes already exist in the DB
rows=`su postgres -c "psql evacs 2>/dev/null <<EOF
  select count(*) from barcode;
EOF" | cut -d\( -f1`
b_rows=`echo $rows | sed 's/count ------- //g'` 
if [ $b_rows -gt 0 ]; then
  echo "$b_rows barcodes already exist in the database!!"
  echo "Delete all existing Barcodes and generate new ones?"
  echo "Press Y to continue, any other key to abort and return to menu."
  read ans
  echo
  if [[ "$ans" == "Y" || "$ans" == "y" ]] ; then
    su postgres -c "psql evacs 2>$EVACS_ERRLOG <<EOF
    delete from barcode;
EOF" 
    if [ -s $EVACS_ERRLOG ]; then
      bailout "Could not delete existing barcodes"
    fi
    rm -rf $BARCODES_DIR/*
  else
    bailout "Exiting on user request"
  fi
fi

if [ ! -f ./BarcodeNumbers ]; then
   checkfile $EVACS_HOME/var/www/html/data/BarcodeNumbers
   cp $EVACS_HOME/var/www/html/data/BarcodeNumbers .
fi

if [ -d $BARCODES_DIR ]; then
  echo "Removing existing postscript files, please wait..."
  rm -rf $BARCODES_DIR
fi

echo "Creating barcode postscript files, please wait..."
createdir $BARCODES_DIR

# SIPL 2011-06-07: Added missing code from 2001 version of
#                  setup_election/setup_election.sh.
su postgres -c "./check_central_scrutiny_bin"  ||
    bailout "Setting up central scrutiny electronic batches failed"

for pp in `cat ./BarcodeNumbers | sed "s/ /_/g" | sed "s/(/\\(/g" | sed "s/)/\\)/g" | cut -d, -f1 | sort -u`
do
    real_pp=`echo $pp | sed "s/_/ /g" | tr "(" "\\(" | tr ")" "\\)" `
    echo Creating Barcodes for \"$real_pp\"....
    createdir $BARCODES_DIR/$pp
    chmod 777 $BARCODES_DIR/$pp
    su postgres -c "./gen_barcodes_bin \"$real_pp\" $BARCODES_DIR/\"$pp\"" || bailout "Creating barcodes for $real_pp failed"
done

# SIPL 2011-09-15 Success; remove the error log file.
rm -f $EVACS_ERRLOG 2>/dev/null

echo
echo
echo
echo  Barcodes generated successfully! It is strongly recommended that you backup the database now.
echo
echo
echo
exit 0
                                                                                                                                                             
