#!/bin/sh

# SIPL 2011-07-18 New script.

# This script generates part of the caption used on the bottom
# line of the screen.  It is invoked by screen as part
# of the caption specification in screenrc.

# Get the name of this polling place.
polling_place_name=`su - postgres -c"psql -A -t evacs <<EOF
SELECT name FROM polling_place
  WHERE code = (SELECT polling_place_code FROM server_parameter);
EOF"`

# Pad out with spaces so as to be at least 30 characters;
# then truncate to exactly 30 characters.
polling_place_name="${polling_place_name}                              "
polling_place_name=${polling_place_name:0:30}


# Get the election date from the database (DD Month YYYY), 
# and convert it to ISO 8601 format (YYYY-MM-DD).
election_date=`su - postgres -c"psql -A -t evacs <<EOF
SELECT to_date(election_date,'DD Month YYYY') FROM master_data ;
EOF"`

while ((1)); do
  today="$(date +'%F')"
  if [[ $today = $election_date ]]; then
      day_indicator="Polling Day"
  elif [[ $today < $election_date ]]; then
      day_indicator="Pre-Polling"
  else
      day_indicator="Post Election"
  fi

  echo "$polling_place_name   $day_indicator"
  if (( $? != 0 )); then
    # The echo failed.
    # Most likely, screen has exited.  So this script must exit quietly too.
    exit
  fi
  sleep 60
done
