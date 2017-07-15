/* This file is (C) copyright 2001-2004 Software Improvements, Pty Ltd */

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

/* Database interface routines for counting. */
#include <stdlib.h>
#include <string.h>
#include <common/database.h>
#include "ballot_iterators.h"
#include "candidate_iterators.h"
#include "fetch.h"

/* Case-insensitive search for electorate: NULL if not found. */
struct electorate *fetch_electorate(PGconn *conn, const char *ename)
{
	struct electorate *elec;
	PGresult *result;

	/* SIPL 2014-05-20 Support electorate names with apostrophes. */
	char escaped_ename[strlen(ename) * 2 + 1];
	size_t escaped_ename_length;
	int escape_error;

	/* SIPL 2014-05-20 Escape the electorate name so that it
	   can be passed to the SQL SELECT statement. */
	escaped_ename_length = PQescapeStringConn (conn,
			   escaped_ename, ename, strlen(ename),
			   &escape_error);
	if (escape_error != 0) {
		return NULL;
	}

	result = SQL_query(conn,
			   "SELECT code, seat_count FROM electorate "
			   "WHERE name = '%s';", escaped_ename);
	if (PQntuples(result) != 1) {
		PQclear(result);
		return NULL;
	}

	elec = malloc(sizeof(*elec) + strlen(ename)+1);
	elec->code = atoi(PQgetvalue(result, 0, 0));
	elec->num_seats = atoi(PQgetvalue(result, 0, 1));
	strcpy(elec->name, ename);
	elec->next = NULL;

	PQclear(result);

	return elec;
}

/* Given the non-NULL electorate, fill in all the groups, return number. */
unsigned int fetch_groups(PGconn *conn, 
			  const struct electorate *elec,
			  struct group *groups)
{
	PGresult *result;
	unsigned int i;

	result = SQL_query(conn,
			   "SELECT name, abbreviation, index FROM party "
			   "WHERE electorate_code = %u "
			   "ORDER by index;", elec->code);
	for (i = 0; i < PQntuples(result); i++) {
		groups[i].name = strdup(PQgetvalue(result, i, 0));
		groups[i].abbrev = strdup(PQgetvalue(result, i, 1));
		groups[i].group_index = atoi(PQgetvalue(result, i, 2));
	}
	PQclear(result);
	return i;
}
/* Find a group by index */
static struct group *find_group(struct group *groups, unsigned int index)
{
	while (groups->group_index != index)
		groups++;
	return groups;
}

/* Given the group information, return the candidate list */
struct cand_list *fetch_candidates(PGconn *conn, 
				   const struct electorate *elec,
				   struct group *groups)
{
	struct cand_list *list = NULL;
	unsigned int i;
	PGresult *result;

	/* By returning them in order, we help the scrutiny sheet generation */
	result = SQL_query(conn,
			   "SELECT name, index, party_index FROM candidate "
			   "WHERE electorate_code = %u "
			   "ORDER BY party_index DESC, name DESC;", elec->code);
	for (i = 0; i < PQntuples(result); i++) {
		list = new_cand_list(malloc(sizeof(struct candidate)), list);
		list->cand->name = strdup(PQgetvalue(result, i, 0));
		list->cand->db_candidate_index
			= atoi(PQgetvalue(result, i, 1));
		list->cand->group = find_group(groups,
					       atoi(PQgetvalue(result, i, 2)));
		list->cand->count_when_quota_reached = 0;
		/* We are PREpending to list, so count is backwards */
		list->cand->scrutiny_pos = PQntuples(result) - i - 1;
		/* All piles empty, all totals 0 */
		memset(list->cand->c, 0, sizeof(list->cand->c));
		/* surplus distributed flag: init false */
		list->cand->surplus_distributed=false;

		/* 2011-05-27 SIPL: Add initializer for
		   list->cand->all_vacancies_filled_at_count. */
		list->cand->all_vacancies_filled_at_count = false;
	}
	PQclear(result);
	return list;
}

/* Load a single vote */
static struct ballot *load_vote(PGconn *conn, const char *preference_list)
{
	struct ballot *ballot;
	char *pref_ptr;   
	unsigned int num_preferences=0,i;
	unsigned int pref_number, group_index, db_cand_index;

	for (pref_ptr=(char *)preference_list;
	     strlen(pref_ptr)>=DIGITS_PER_PREF;
	     pref_ptr += DIGITS_PER_PREF*sizeof(char),num_preferences++);
	
	if ( strlen(pref_ptr)) 
		bailout("Malformed preference list: '%s'\n",preference_list);
	
	ballot = malloc(sizeof(*ballot)
			+ sizeof(ballot->prefs[0])*num_preferences);
	ballot->num_preferences = num_preferences;
	ballot->count_transferred = 0;
	
	/* They many not be in order */
	for (pref_ptr=(char *)preference_list, i = 0;
	     i < ballot->num_preferences; 
	     i++,pref_ptr += DIGITS_PER_PREF*sizeof(char) )
	{
		sscanf(pref_ptr,"%2u%2u%2u",&pref_number,&group_index,&db_cand_index);
		
		ballot->prefs[pref_number-1]
			.group_index = group_index;
		ballot->prefs[pref_number-1]
			.db_candidate_index = db_cand_index;
	}
	
	return ballot;
	
}
/* Get all the ballots for this electorate */
/* SIPL 2014-02-06
   A progress bar is printed while loading votes.
   In this function, "hash" refers to the hash symbol "#".
   The progress bar has been implemented in a simple fashion,
   but subject to the following properties:
   1. The progress bar is displayed if there is at least one vote to
      be loaded.
   2. When loading of votes is completed, the progress bar will always
      be filled to the end (i.e., showing 100% complete).
   3. Because the progress bar marks 5% progress, there are only
      20 hashes to be printed. This means the progress bar is
      a "rounded" version of progress.  Progress is rounded _down_,
      which means that the progress bar always "lags" behind actual
      progress.
   4. For large numbers of votes, the lag is insignificant and the progress
      bar does in fact closely correspond to actual progress.
   5. For small (less than, say, 100) votes,
      the progress bar may not closely correspond to progress:
      the votes may have all been loaded well before the progress bar
      reaches the end.  But in such cases, the loading process
      is over so quickly anyway that the user will not notice.
   6. In any case, because of rounding down, loading usually completes
      with not enough hashes having been printed. In this case,
      extra hashes are then printed to fill out the progress bar to
      the end.
*/

/* SIPL 2014-02-07 The original code has a hard-coded 20-character
   progress bar, with each hash representing five percent. Hence the
   naming of variables such as "five_percent".  Nevertheless, these
   2014 modifications try not to assume that.
   So, here is a new constant that determines the number of spaces in
   the gap between the two vertical bars of the progress bar, and,
   therefore, the number of hashes to be printed. */
#define HASHES_TO_PRINT 20

struct ballot_list *fetch_ballots(PGconn *conn, const struct electorate *elec)
{
	struct ballot_list *list = NULL;
	PGresult *result;
	unsigned int i,num_votes,five_percent;
	/* SIPL 2014-03-25 Need to back up 24 spaces. */
	const char backspace_by_24[] = {
	"\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
	};
	/* SIPL 2014-05-20 Support electorate names with spaces. */
	char elec_name_normalized[strlen(elec->name) + 1];

	/* SIPL 2014-02-06
	   Additional variables needed to get progress bar correct. */
	int hashes_printed = 0;
	int next_count_at_which_to_print_hash;

	normalize_electorate_name(elec_name_normalized, elec->name);
	result = SQL_query(conn,
			   "SELECT preference_list " 
			   "FROM %s_confirmed_vote; "
			   , elec_name_normalized);

	num_votes =  PQntuples(result);
	/* SIPL 2014-02-06 This is a convenient way of computing
	   five_percent = ceiling (num_votes / HASHES_TO_PRINT).
	   Now, five_percent will be zero only if num_votes is zero.
	*/
	five_percent = ((num_votes + HASHES_TO_PRINT - 1) / HASHES_TO_PRINT);
	if (five_percent != 0) {
	  /* SIPL 2014-02-07 Initialization of counters
	     for the progress bar. */
	  hashes_printed = 0;
	  /* Subtract 1, because counting of votes starts at 0. */
	  next_count_at_which_to_print_hash =
	    five_percent * (hashes_printed + 1) - 1;
	  /* SIPL 2014-02-06 Actually print 20 spaces, not 21. */
	  fprintf(stderr,"%s", (const char *) "0|                    |100");
	  fprintf(stderr,"%s",backspace_by_24);
	}

	for (i = 0; i < num_votes; i++) {
	        list = new_ballot_list( load_vote(conn,PQgetvalue(result, i, 0)),list);
		if (five_percent != 0) {

		  /* SIPL 2014-02-06 Fix printing of hashes */
		  if (i ==  next_count_at_which_to_print_hash) {
		    fprintf(stderr, "#");
		    hashes_printed++;
		    /* Subtract 1, because counting of votes starts at 0. */
		    next_count_at_which_to_print_hash =
			    five_percent * (hashes_printed + 1) - 1;
		  }
		}
	}
	if (five_percent != 0) {
		/* For a small number of ballots, the progress bar
		   may finish short of the end. So print as many extra
		   hashes as needed to fill it up. */
		while (hashes_printed < HASHES_TO_PRINT) {
			fprintf(stderr, "#");
			hashes_printed++;
		}
		fprintf(stderr, "\n");
	}
	PQclear(result);
	return list;
}
