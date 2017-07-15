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
#include <common/evacs.h>
#include "gen_barcodes.h"

/* DDSv1A-3.1.2: Generate Barcodes */
int main(int argc, const char *argv[])
{
	PGconn *conn;
	struct polling_place *pp;

	if (argc != 3)
		bailout("Usage: gen_barcodes_bin <polling place> <dir>\n"
			"(must be run in Election Setup Information"
			" directory)\n");

	/* Open a connection to a builtin database */
	conn = connect_db(DATABASE_NAME);
	if (!conn)
		bailout("Connection to database '%s' failed: %s.\n",
			DATABASE_NAME, PQerrorMessage(conn));

	/* Generate the barcodes for this polling place */
	pp = get_polling_place(conn, argv[1]);
	if (!pp)
		bailout("Polling place `%s' not found!\n", argv[1]);
	barcodes_pp(conn, pp, argv[2]);

	free(pp);
	PQfinish(conn);
	return(0);
}
