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
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.. */
#include <stdlib.h>
#include <common/evacs.h>
#include <common/database.h>
#include <common/createtables.h>
#include <common/find_errors.h>
#include <common/batch.h>

/* check that there is an electronic batch for each electorate*/
/* For the Central Scrutiny  */
int main(int argc, const char *argv[])
{
	PGconn *conn;
	int pp;
	struct electorate *elec_ptr;
	char *batchname;
	PGresult *result;


	/* Open a connection to a builtin database */
	conn = connect_db(DATABASE_NAME);
	if (!conn)
		bailout("Connection to database '%s' failed: %s.\n",
			DATABASE_NAME, PQerrorMessage(conn));

	/* Get polling place to use when less than 20 votes in electorate */
	pp = resolve_polling_place_code(conn, "Central Scrutiny");

	if ( pp < 0 )
		/* The fallback CSC code is .. */
		pp = 400;
	
	/* get all electorate data */
	elec_ptr=get_electorates(conn);

	/* for all electorates */
	for (;elec_ptr;elec_ptr=elec_ptr->next) 
	{
	    batchname=get_batch_number_string(elec_ptr->code, pp);
	    result = SQL_query(conn,
			   "SELECT * from batch WHERE number = '%s';",
			   batchname);
	    if (PQntuples(result) == 0) {
		/*batch does not exist */
		/*create batch */
	        SQL_command(conn,"INSERT INTO batch VALUES(%s,%u,%u);",
				    batchname,
			            pp,elec_ptr->code);
	    }
	    PQclear(result);
	    free(batchname);
	}

	PQfinish(conn);
	return(0);
}
