#! /bin/sh

# This script looks for the latest Election Setup Log File and displays the last line of the log file.
# Useful if the user forgets if the Setup is already done and whether they stuffed it up.
                                                                                                                                                             
                                                                                                                                                             
# All constants for this file are defined up here.
SETUP_DIR=/tmp/setup    # Scratch directory
P1_LOG_FILE=$SETUP_DIR/Phase-1.*.log  #  Log File for Setup Phase-1
P2_LOG_FILE=$SETUP_DIR/Phase-2.*.log  #  Log File for Setup Phase-1
                                                                                                                                                             
countP1=`ls -lt $P1_LOG_FILE 2>/dev/null | awk '{print $9}' | wc -l`
P1=`ls -lt $P1_LOG_FILE 2>/dev/null | awk '{print $9}'`

countP2=`ls -lt $P2_LOG_FILE 2>/dev/null | awk '{print $9}' | wc -l`
P2=`ls -lt $P2_LOG_FILE 2>/dev/null | awk '{print $9}'`


if [ $countP1 -gt 0 ]; then
  echo eVACS Election Data Setup Phase-1 was executed on:
  for x in `echo $P1`
  do
    tail -1 $x
  done
else
  echo eVACS Election Data Setup Phase-1 was never executed.
fi
echo; echo; echo

if [ $countP2 -gt 0 ]; then
  echo eVACS Election Data Setup Phase-2 was executed on:
  for x in `echo $P2`
  do
    tail -1 $x
  done
else
  echo eVACS Election Data Setup Phase-2 was never executed.
fi
echo; echo; echo


exit 0
                                                                                                                                                             
