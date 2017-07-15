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
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <limits.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <common/barcode.h>
#include <common/barcode_hash.h>
#include <common/evacs.h>
#include <common/database.h>
/* SIPL 2014-05-19 No longer used.
 #include <common/createtables.h> */
#include "setup_election.h"
#include "draw_barcode.h"
#include "gen_barcodes.h"

#define BARCODE_NUMBER_FILE "BarcodeNumbers"

#define BARCODES_PER_DIRECTORY 160

/* DDSv1A-3.2.1: Generate Random Number */
static void gen_random(unsigned char randnum[], size_t size)
{
	static int fd = 0;

	/* /dev/urandom contains random numbers under Linux */
	if (fd == 0)
		fd = open("/dev/urandom", O_RDONLY, 0);

	/* Each read *may* return short, but read wrapper loops for us. */
	read(fd, randnum, size);
}

/* DDSv1A-3.2.1: Generate Table Entry */ 
static void gen_entry(PGconn *conn,
		      const struct barcode *bc,
		      unsigned int ppcode,
		      unsigned int ecode)
{
	char hash[HASH_BITS + 1];

	/* Create SHA hash of the barcode random data */
	gen_hash(hash, bc->data, sizeof(bc->data));

	/* Create and execute SQL command */
	/* DDSv1A-3.2.1: Store Table Entry */
	SQL_command(conn,
		    "INSERT INTO barcode VALUES ( B'%s', %u, %u );",
		    hash, ppcode, ecode);
}

/* DDSv1A-3.2.1: Generate Barcode Image */
static char *gen_bc_image(struct barcode *bc,
			  const char *ppname,
			  const char *ename)
{
	bc->checksum = gen_csum(bc);

	return draw_barcode(bc, ppname, ename);
}

/* DDSv1A-3.2.1: Generate One Barcode */
/* You must free the returned string. */
static char *gen_barcode(PGconn *conn,
			 const struct polling_place *pp,
			 const struct electorate *elec)
{
	struct barcode bc;

	gen_random(bc.data, sizeof(bc.data));
	gen_entry(conn, &bc, pp->code, elec->code);
	return gen_bc_image(&bc, pp->name, elec->name);
}

/* DDSv1A-3.2.1: Generate Barcode Page */
static void gen_barcode_page(PGconn *conn,
			     const struct polling_place *pp,
			     const struct electorate *elec,
			     const char *filename)
{
	char *image;
	int bcfile;

	/* Open output file */
	bcfile = open(filename, O_WRONLY|O_CREAT|O_EXCL, 0600);
	if (bcfile < 0)
		bailout("Could not open %s: %s\n", filename, strerror(errno));

	image = gen_barcode(conn, pp, elec);
	print_full_page(image, bcfile);
	free(image);
	close(bcfile);
}

/* DDSv1A-3.2.1: Prompt for Number of Pages of Barcodes */
static unsigned int get_num_barcodes(const char *ppname, const char *ename)
{
	FILE *nums;
	char *line;
	char looking_for[strlen(ppname) + 1 + strlen(ename) + 2];

	sprintf(looking_for, "%s,%s,", ppname, ename);
	nums = fopen(BARCODE_NUMBER_FILE, "r");
	if (!nums)
		bailout("Could not open %s file: %s\n",
			BARCODE_NUMBER_FILE, strerror(errno));
	while ((line = fgets_malloc(nums)) != NULL) {
		if (strncmp(line, looking_for, strlen(looking_for)) == 0) {
			int num;
			num = atoi(line + strlen(looking_for));
			if (num <= 0)
				bailout("Bad line in %s: %s\n",
					BARCODE_NUMBER_FILE, line);
			free(line);
			printf("Preparing %u barcodes for %s/%s\n",
			       num, ppname, ename);
			fclose(nums);
			return (unsigned int)num;
		}
		free(line);
	}
	fclose(nums);
	return 0;
}

static void check_electronic_batch(PGconn *conn, 
			     int pp,
			     int elec)
{
	PGresult *result;
	char *batchname;

	/* 2014-02-21 Support adding pre-poll electronic batches. */
	/* There will now be two queries to keep track of. */
	PGresult *result2;
	/* The pre-poll polling place code corresponding to pp,
	   if there is one. */
	int pp_prepoll;

	batchname=get_batch_number_string(elec, pp);
	result = SQL_query(conn,
			   "SELECT * from batch WHERE number = '%s';",
			   batchname);
	if (PQntuples(result) == 0) {
		/*batch does not exist */
		/*create batch */
	        SQL_command(conn,"INSERT INTO batch VALUES(%s,%u,%u);",
				    batchname,
			            pp,elec);
	} 
	PQclear(result);
	free(batchname);

	/* 2014-02-21 Now also ensure that there is an electronic
	   batch added for the pre-poll batch corresponding to
	   this polling place code, if there is one.
	   Note from the specification of the data in
	   doc/changes/2012/database-changes-2012.txt that
	   there is a corresponding pre-poll polling place
	   code iff pre_polling_code is greater than or equal to 0. */
	result2 = SQL_query(conn,
			   "SELECT pre_polling_code from polling_place "
			   "WHERE code = %d AND pre_polling_code >= 0;",
			   pp);
	if (PQntuples(result2) != 0) {
		/* There will be exactly one match, as code is
		   the primary key of the polling_place table. */
		pp_prepoll = atoi(PQgetvalue(result2, 0, 0));
		batchname=get_batch_number_string(elec, pp_prepoll);
		result = SQL_query(conn,
				   "SELECT * from batch WHERE number = '%s';",
				   batchname);
		if (PQntuples(result) == 0) {
			/* The pre-poll batch does not exist, so */
			/* create it. */
			SQL_command(conn,"INSERT INTO batch VALUES(%s,%u,%u);",
				    batchname,
			            pp_prepoll,elec);
		}
		PQclear(result);
		free(batchname);
	}
	PQclear(result2);

}


/* DDSv1A-3.2.1: Barcodes for Polling Place and Electorate */
static void barcodes_pp_elec(PGconn *conn, 
			     const struct polling_place *pp,
			     const struct electorate *elec,
			     const char *dirname)
{
	unsigned int i, num, group;
	char filename[strlen(dirname) + 1
		     + INT_CHARS + sizeof("-") + INT_CHARS
		     + strlen(elec->name) + 2
		     + strlen(pp->name) + 1
		     + strlen(elec->name) + 1
		     + INT_CHARS + sizeof(".ps")];
	char elec_name_normalized[strlen(elec->name) + 1];

	normalize_electorate_name(elec_name_normalized, elec->name);

	/* make sure there's a batch to put the electronic votes in */
	check_electronic_batch(conn, pp->code, elec->code);

	/* Because MSDOS is not a real disk format, there is a limit
	   (about 200) to the number of entries in one directory.
	   Hence we have to do this in groups. */
	num = get_num_barcodes(pp->name, elec->name);
	/* Need to round UP, not down here */
	for (group = 0;
	     group < (num+BARCODES_PER_DIRECTORY-1)/BARCODES_PER_DIRECTORY;
	     group++) {
		sprintf(filename, "%s/%s-%u-%u", dirname,
			elec_name_normalized,
			group * BARCODES_PER_DIRECTORY + 1,
			(group + 1) * BARCODES_PER_DIRECTORY);
		mkdir(filename, 0755);
	}

	for (i = 0; i < num; i++) {
		group = i / BARCODES_PER_DIRECTORY;
		/* Create the filename for it to go out on */
		sprintf(filename, "%s/%s-%u-%u/%u-%u.%u.ps",
			dirname,
			elec_name_normalized,
			group * BARCODES_PER_DIRECTORY + 1,
			(group + 1) * BARCODES_PER_DIRECTORY,
			pp->code, elec->code, i+1);
		gen_barcode_page(conn, pp, elec, filename);
	}
}

/* DDSv1A-3.2.1: Barcodes for Polling Place */
void barcodes_pp(PGconn *conn,
		 const struct polling_place *pp,
		 const char *dirname)
{
	struct electorate *elecs, *elec;

	/* Do the writing of the PostScript files */
	elecs = get_electorates(conn);
	for (elec = elecs; elec; elec = elec->next)
		barcodes_pp_elec(conn, pp, elec, dirname);
	free_electorates(elecs);
}








