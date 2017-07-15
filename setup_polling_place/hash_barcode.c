/* This file is (C) copyright 2001 Software Improvements, Pty Ltd */

/* This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <common/barcode.h>
#include <common/barcode_hash.h>
#include <common/evacs.h>

int main(int argc, char *argv[])
{
	char hash1[HASH_BITS + 1];
	struct barcode bc;

	if (argc != 2)
		bailout("Require barcode id to hash as an argument.\n");

	if (strlen(argv[1]) != BARCODE_ASCII_BYTES)
		bailout("Barcode should have %u characters, not %u!\n",
			BARCODE_ASCII_BYTES, strlen(argv[1]));

	strcpy(bc.ascii, argv[1]);
	if (!bar_decode_ascii(&bc))
		bailout("This barcode has an invalid character.\n");
	if (gen_csum(&bc) != bc.checksum)
		bailout("This barcode has been entered incorrectly.\n");

	gen_hash(hash1, bc.data, sizeof(bc.data));
	printf("%s\n", hash1);
	exit(0);
}

