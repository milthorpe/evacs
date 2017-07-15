#!/bin/sh
# This file is (C) copyright 2001-2011 Software Improvements, Pty Ltd
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


# Check if a barcode is used, either by typing in the
# code printed on it, or by swiping it through a barcode
# reader.

# The code has been moved from pp_start.sh into this file
# so that the kill command kills only child processes
# of this task.  (If the kill command were done in
# pp_start.sh, it would also kill the clock.)

FIFO=/tmp/fifo

# Trap Control-C.
trap "cleanup" SIGINT SIGTERM

cleanup() {
  kill $(jobs -p) >& /dev/null
  rm -f $FIFO
  exit 0
}

rm -f $FIFO
mkfifo $FIFO

# Now redirect terminal input to the FIFO.
cat /dev/tty >>$FIFO 2>/dev/null &

if [[ -e /dev/ttyUSB0 ]] ; then
  # Barcode reader connected via serial-to-USB adapter
  SERIAL_DEVICE=/dev/ttyUSB0
else
  # Barcode reader connected via inbuilt serial port
  SERIAL_DEVICE=/dev/ttyS0
fi

# Use icrnl to deal with any incoming carriage return.
stty raw 9600 icrnl < $SERIAL_DEVICE

# Redirect the barcode reader (if any) to the FIFO.
cat $SERIAL_DEVICE >> $FIFO 2>/dev/null &

# Now both terminal input and the barcode reader are connected
# to the FIFO.

clear > /dev/tty
echo > /dev/tty
echo "Swipe the barcode." > /dev/tty
echo -n "Or, enter barcode digits and press ENTER: " > /dev/tty

# Read the barcode from the FIFO.
read BARCODE < $FIFO

# Cleanup now.
kill $(jobs -p) >& /dev/null
rm -f fifo.txt

echo > /dev/tty
echo > /dev/tty

HASH=`./hash_barcode "$BARCODE"`
if [ $? -ne 0 ]; then
  echo Perhaps you entered the barcode incorrectly.
else
  echo "SELECT used FROM barcode WHERE hash='$HASH';" | \
      su - postgres -c "psql evacs" > /tmp/pp_start.out
  if [ `head -3 /tmp/pp_start.out | tail -1` == "t" ] 2>/dev/null; then
    echo The barcode HAS been used. 
  elif [ `head -3 /tmp/pp_start.out | tail -1` == "f" ] 2>/dev/null; then
    echo The barcode has NOT been used. 
  else
    echo That barcode does not seem to be in the database at all.
    echo Perhaps you entered the barcode incorrectly.
  fi
fi
echo Press RETURN to go back to the menu.
read
