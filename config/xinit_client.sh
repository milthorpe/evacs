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

# 2011-05-16 Richard Walker
# xinit is now in /usr/bin
#PATH=${PATH}:/usr/X11R6/bin
#export PATH

# Old code for resolution auto-detection follows:

## # If were on the Voting Machine change resolution to 1024x768, else 1152x864
## 
## # test for voting machine by looking for two master HDD on primary & secondary
## DISK1=`grep disk /proc/ide/hda/media`
## DISK2=`grep cdrom /proc/ide/hdc/media`
## 
## if [[ -n $DISK1 && -n $DISK2 ]] ;
## then
##     sed -i 's/^\(.*\)Modes.*$/\1Modes    "1152x864"/' /etc/X11/XF86Config
##     RESOLUTION="1152 864"
## else
##     sed -i 's/^\(.*\)Modes.*$/\1Modes    "1024x768"/' /etc/X11/XF86Config
##     RESOLUTION="1024 768"
## fi
## /usr/X11R6/bin/xinit /opt/eVACS/bin/voting_client_bin $RESOLUTION

# 2011-05-16 Richard Walker
#   1. xinit is now in /usr/bin
#   2. Force 16-bit visual, as the default now seems to be 24.  The
#      voting client code assumes a 16-bit visual.
# 2008-07-25 Richard Walker
# New code relies on getting the resolution from /opt/eVACS/bin/resolution.txt.
# It is the responsibility of fixXF86Config.pl to make sure that
# that file exists and has the correct contents.

/usr/bin/xinit /opt/eVACS/bin/voting_client.sh
