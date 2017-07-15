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
#include <stdio.h>
#include <stdlib.h>
/*#include <common/safe.h>*/
#include "fetch_rotation.h"

struct rotation *fetch_rotation(PGconn *conn,
				unsigned int rotation_num,
				unsigned int seat_count)
{
	struct rotation *rot;
	char *rotstring;
	/* SIPL 2014-03-18 Additional variables to support
	   arbitrary number of seats in the rotation. */
	char *rotstring_cursor;
	int rotation_index;
	int sscanf_offset;

	/* Get the rotation */
	rotstring = SQL_singleton(conn,
				 "SELECT rotation "
				 "FROM robson_rotation_%u "
				 "WHERE rotation_num = %u;",
				 seat_count, rotation_num);
	if (rotstring == NULL)
		return NULL;

	rot = malloc(sizeof(*rot));
	rot->size = seat_count;

	/* 2014-03-18 Support an arbitrary (> 1) number of positions
	   in the rotation.
	   See also fetch_rotation() in tools/export_ballots.c
	   and tools/export_confirmed.c.
	*/
	/* rotation is in the form {n,n,n,n,n} */
	rotstring_cursor = rotstring;
	sscanf(rotstring_cursor, "{%u%n", &rot->rotations[0],
	       &sscanf_offset);
	rotstring_cursor += sscanf_offset;
	rotation_index = 1;
	while ((rotation_index < seat_count) &&
	       (sscanf(rotstring_cursor, ",%u%n",
		       &rot->rotations[rotation_index],
		       &sscanf_offset) == 1)) {
		rotstring_cursor += sscanf_offset;
		rotation_index++;
	}

	free(rotstring);
	return rot;
}
