#!/usr/bin/perl

# SIPL 2014-05-30 Filter for barcode data when read via USB hidraw.

# Don't buffer stdout.
$| = 1;

my $rc;
my $data;

while (1) {
    # Use sysread, to bypass any Perl internals and go straight to stdin
    $rc = sysread (STDIN, $data, 128);
    if (defined $rc) {
	if ( $rc > 0 ) {
	    # Remove all non-printable characters.
	    $data =~ s/[^[:print:]]//g;
	    # Send data to stdout, with carriage-return terminator.
	    print $data,"\r";
	}
    }
    else {
	die "sysread error: $!";
    }
}
