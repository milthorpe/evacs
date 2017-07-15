#!/usr/bin/perl -w

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

# Author: Raffaele Filardo
# Date: 7 July 2004
# Purpose: Modifies XF86Config file for 1152x864 (with 1024x768 as drop-back resolution)
#          w/16bpp display mode only
#
# Assumes:
# - XF86Config already created by 'X -configure' or similar method
# - Only one screen on one graphics card capable of above specs
#

use strict;
use diagnostics;
use Getopt::Std;


our($opt_i);
getopts('i:');

my $backupFilename;
my $tempFilename;
my $foundSection;
my $tempSubSection;
my $foundSubSection;
my $foundDepth;
my $foundModes;


if (!defined($opt_i)) {
    die "fixXF86Config -i <full path to XF86Config file>\n";
}

$backupFilename = "$opt_i.backup";
$tempFilename   = "$opt_i.temp";

if (-e $backupFilename) {
	 exit 0;
}

open(IFILE, "<$opt_i") or die "Couldn't open \"$opt_i\": $!\n";
open(OFILE, ">$tempFilename") or die "Couldn't open \"$tempFilename\": $!\n";

# Scroll down to 'Section "Screen"'
$foundSection = 0;
while ($foundSection == 0) {
	 $_ = <IFILE>;

	 if (m/^Section\s+"Screen"$/) {
		  $foundSection = 1;
	 }

	 print OFILE $_;
}


PARSE_SCREEN_SECTION:
$foundSubSection = 0;

while (<IFILE>) {
	 if (m/^(\s+DefaultDepth\s+)([0-9]{1,2})$/) {
		  print OFILE $1 . "16\n";
	 }
	 elsif (m/^\s+SubSection\s*"Display"$/) {
		  $tempSubSection  = $_;
		  $foundDepth      = 0;
		  $foundModes      = 0;

		  while (<IFILE>) {
				if (m/^(\s+Depth\s+)([0-9]+)$/) { # || m/\s+FbBpp\s([0-9]{1,2})$/) {
					 $tempSubSection .= $1 . "16\n";
					 $foundDepth = 1;
				}
				elsif (m/^(\s+Modes\s+)".*"$/) {
					 if ($foundModes == 0) {
						  $tempSubSection .= $1 . "\"1152x864\" \"1024x768\"\n";
						  $foundModes = 1;
					 }
				}
				elsif (m/^\s+EndSubSection$/) {
					 if ($foundDepth == 0) {
						  $tempSubSection .= "\t\tDepth    16\n";
					 }

					 if ($foundModes == 0) {
						  $tempSubSection .= "\t\tModes    \"1152x864\" \"1024x768\"\n";
					 }

					 $tempSubSection .= $_;

					 if ($foundSubSection == 0) {
						  print OFILE $tempSubSection;
						  $foundSubSection = 1;
					 }
					 last;
				}
				else {
					 $tempSubSection .= $_;
				}
		  }
	 }
	 elsif (m/^EndSection$/) {
		  print OFILE $_;
		  last;
	 }
	 else {
		  print OFILE $_;
	 }
}


# Get the rest of the file
while (<IFILE>) {
	 if (m/^Section\s+"Screen"$/) {
		  goto PARSE_SCREEN_SECTION;
	 }

	 print OFILE $_;
}


close(IFILE);
close(OFILE);

rename($opt_i, $backupFilename) or die "Couldn't backup \"$opt_i\" to \"$backupFilename\": $!\n";
rename($tempFilename, $opt_i) or die "Couldn't rename \"$tempFilename\" to \"$opt_i\": $!\n";

exit 0;
