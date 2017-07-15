/* This file is (C) copyright 2003 NICTA, Pty Ltd */

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
#include <string.h>
#include <assert.h>

#include <common/database.h>
#include <common/evacs.h>
#include <common/createtables.h>

/// Constants declared for input filenames AND PATHS:  The electorates, groups and candidates are
/// all from single files.  The ballot information is supplied per electorate and processed as such.
///
/// NOTES: The ballots data files AND PATHS are specified in load_2001_ballots()
/// All lines in the csv file contain valid records (i.e. field/column name headers were removed)
/// All input CSV files contain unix text, no extraneous whitespace, 
/// character ' appears as \' (i.e. names of candidates have apostrophes escaped), 
/// field/column names do not appear on the first line, each line in the file is a valid record
/// 
const char* electorates_data_file = "data/test_set/electorates.txt";//< This is used by load_2001_electorates()
const char* groups_data_file      = "data/test_set/tblGroups.txt";  //< This is used by load_2001_groups()
const char* candidates_data_file  = "data/test_set/tblCands.txt";   //< This is used by load_2001_candidates()

//const char* electorates_data_file = "data/2001/electorates.txt";//< This is used by load_2001_electorates()
//const char* groups_data_file      = "data/2001/tblGroups.txt";  //< This is used by load_2001_groups()
//const char* candidates_data_file  = "data/2001/tblCands.txt";   //< This is used by load_2001_candidates()


/*! Get the next token from the comma separated (CSV) stream 
    @Pre there must be a valid token
*/
static char* get_csv_token(FILE* csvfile, char* token){

  int index = 0;
  int inchar;

  inchar = fgetc(csvfile);
  token[index] = (char)inchar;
  while ( (token[index] != ',') && (token[index] != '\n') && (!feof(csvfile)) ){
      index++;
      //}
    inchar = fgetc(csvfile);
    token[index] = (char)inchar;
  }
  token[index] = (char)NULL;
  return token;
}


static void load_2001_electorates(PGconn *conn)
{
  char buff[512];
  int record_count = 0;

  int  ecode = 0;
  char name[255];
  int  seat_count = 0;
  int  num_electors = 0;
  char colour[255];

  FILE* f = fopen(electorates_data_file,"r");
  if (f == NULL)bailout("Can't open file:%s\n",electorates_data_file);

  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      ecode = atoi(buff);
      strcpy(name,get_csv_token(f,buff));
      seat_count = atoi(get_csv_token(f,buff));
      strcpy(colour, get_csv_token(f,buff));
      record_count++;
      SQL_command(conn,"INSERT INTO electorate"
		  "(code, name, seat_count, number_of_electors,colour) "
		  "VALUES(%u,'%s', %u, %u, '%s');",
		  ecode,name,seat_count,num_electors,colour
	);

    }    
  }
  printf("Loaded %d electorates.\n",record_count);
}

static void load_2001_groups(PGconn *conn)
{
  char buff[512];
  int  record_count = 0;

  int  index = 0;
  int  ecode = 0;
  int  pcode = 0;
  char name[255];
  char abbrev[255];
  int num_cands = 0;

  FILE* f = fopen(groups_data_file,"r");
  if (f == NULL)bailout("Can't open file:%s\n",groups_data_file);

  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      index = atoi(buff);
      ecode = atoi(get_csv_token(f,buff));
      pcode = atoi(get_csv_token(f,buff));
      strcpy(name,get_csv_token(f,buff));
      strcpy(abbrev,get_csv_token(f,buff));
      num_cands = atoi(get_csv_token(f,buff));
      record_count++;      
      SQL_command(conn,"INSERT INTO party"
		  "(electorate_code, index, name, abbreviation) "
		  "VALUES(%u, %u, '%s', '%s');",
		  ecode,pcode, name,abbrev
	);
    }    
  }
  printf("Loaded %d groups (parties).\n",record_count);
}

static void load_2001_candidates(PGconn *conn)
{
  char buff[512];
  int record_count = 0;

  int  index = 0;
  int  ecode = 0;
  int  pcode = 0;
  int  ccode = 0;
  char name[255];

  FILE* f = fopen(candidates_data_file,"r");
  if (f == NULL)bailout("Can't open file:%s\n",candidates_data_file);

  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      index = atoi(buff);
      ecode = atoi(get_csv_token(f,buff));
      pcode = atoi(get_csv_token(f,buff));
      ccode = atoi(get_csv_token(f,buff));
      strcpy(name,get_csv_token(f,buff));

      record_count++;      
      SQL_command(conn,"INSERT INTO candidate"
		  "(electorate_code, party_index, index, name) "
		  "VALUES(%u, %u, %u, '%s');",
		  ecode,pcode,ccode,name
	);
    }    
  }
  printf("Loaded %d candidates.\n",record_count);
}

static void load_2001_ballots_for_electorate(PGconn *conn, int electorate_code, const char *filename)
{
  
  char buff[512];
  int  record_count = 0;
  int  primary_count = 0;

  int  index = 0;
  int  batch = 0;
  int  bindex = 0;
  int  pref = 0;
  int  ccode = 0;
  int  pcode = 0;
  int  rcand = 0;

  FILE* f = fopen(filename,"r");
  if (f == NULL)bailout("Can't open file:%s\n",filename);

  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      //fldID,batch,pindex,pref,ccode,pcode,rcand
      index  = atoi(buff);
      batch  = atoi(get_csv_token(f,buff));
      bindex = atoi(get_csv_token(f,buff));
      pref   = atoi(get_csv_token(f,buff));
      ccode  = atoi(get_csv_token(f,buff));
      pcode  = atoi(get_csv_token(f,buff));
      rcand  = atoi(get_csv_token(f,buff));

      if (pref == 1) primary_count++;

      record_count++;
      
      SQL_command(conn,"INSERT INTO csv_pref_entry"
		  "(electorate_code, batch, batch_index,"
		  " pref_num, candidate_index, party_index)"
		  "VALUES(%u, %u, %u, %u, %u, %u);",
		  electorate_code,batch,bindex,pref,ccode,pcode
		  );
    }
  }//endwhile
  printf("Loaded %d primary votes and total of %d ballot records from file %s.\n",primary_count,record_count, filename);
}

//======================================================================
// Support routines for dealing with the CSV ballot preference records
//======================================================================

typedef struct csv_pref_record_TAG {
  int  ecode;
  int  batch;
  int  bindex;
  int  pref;
  int  ccode;
  int  pcode;
  int  is_null_record;
} csv_pref_record;

static void set_null_csv_pref_record(csv_pref_record *record)
{
  memset(record,0,sizeof(csv_pref_record));
  record->is_null_record = 1;
}

static int is_null_csv_pref_record(csv_pref_record *record)
{
  return(record->is_null_record);
}

static void get_next_csv_pref_record(PGresult *result, int record_num, csv_pref_record *record)
{
  record->ecode  = atoi(PQgetvalue(result, record_num, 0));
  record->batch  = atoi(PQgetvalue(result, record_num, 1));
  record->bindex = atoi(PQgetvalue(result, record_num, 2));
  record->pref   = atoi(PQgetvalue(result, record_num, 3));
  record->ccode  = atoi(PQgetvalue(result, record_num, 4));
  record->pcode  = atoi(PQgetvalue(result, record_num, 5));
  record->is_null_record = 0;
}

/*
static void print_csv_pref_record(csv_pref_record *record)
{
  printf("%u, %u, %u, %u, %u, %u\n", record->ecode, record->batch,  record->bindex,  
	 record->pref, record->ccode, record->pcode);
}
*/

static void copy_csv_pref_record(csv_pref_record *src,csv_pref_record *dest)
{
  dest->ecode  =   src->ecode;
  dest->batch  =   src->batch; 
  dest->bindex =   src->bindex; 
  dest->pref   =   src->pref; 
  dest->ccode  =   src->ccode; 
  dest->pcode  =   src->pcode;
  dest->is_null_record = src->is_null_record; 
}

static int same_vote_csv_pref_record(csv_pref_record *x,csv_pref_record *y)
{
  return(   (x->ecode == y->ecode) 
	    && (x->batch == y->batch) 
	    && (x->bindex == y->bindex)
	    && (x->is_null_record == y->is_null_record)
	    );
}

/*
  This routine takes the raw data from the table, but in sorted form since the CSV input
  data is not sorted.  This makes it easier to do sanity checks and throw away preferences
  (and subsequent preference indications) that occur twice in one ballot.

  The sanity checking is excessive, but we were concerned with absolute sanity, not runtime.

*/
static void insert_confirmed_csv_ballots(PGconn *conn, int electorate_code)
{
  PGresult *result;
  int primary_count = 0;
  int i;  
  csv_pref_record current, next, null_record;//read buffers and a sentinel
  set_null_csv_pref_record(&null_record);

  result = SQL_query(conn,
		     "SELECT * "
		     "FROM csv_pref_entry "
		     "WHERE electorate_code = %u "
		     "ORDER BY electorate_code, batch, batch_index, pref_num, candidate_index, party_index"
		     ,electorate_code
	      );

  //There is a double buffer of for reading records so we can loo ahead and check validity
  //before commiting to the insert.  
  get_next_csv_pref_record(result,0,&current);
  get_next_csv_pref_record(result,1,&next);
  //There are two cases for a vote to be partially discarded
  //1) It contains a duplicate preference number whose value is greater than 1, or 
  //2) It contains a non-contiguous sequence of preference numbers
  //Solutions:
  //1) The duplicate preference entries and all following (greater in value) preferences are discarded
  //2) All preference entries after the gap are discarded
  i = 2; 
  while (i < (PQntuples(result)+2)){
    int skip_insert = 0;   //true when the record should not be inserted
    int skip_remainder = 0; // true when the rest of the vote should not be inserted

    if (current.pref == 1){
      //do some sanity checking 
      //-- if the next preference record is not null and is part of the current ballot then 
      //    1)assert that the preference number is greater than the current one
      //    2)if the next pref num is not 2 then chuck the rest of this vote
      if ((!is_null_csv_pref_record(&next)) && (same_vote_csv_pref_record(&current,&next)) ){
	assert(next.pref > current.pref);//bomb for this - sql query ORDER error should never happen
	                                 //or an informal vote (two '1's) was recorded
	if (next.pref != 2) //must be ascending order but increment is always by 1
	  skip_remainder = 1;
      }
      else {
	//more sanity checks
	//next preference record is null or must contain a 1 for the preference number (a new vote)
	//  a new vote should have a '1' - bomb when informal vote detected - this should NOT happen
	assert( (is_null_csv_pref_record(&next)) || (next.pref == 1)  );
      }
      primary_count++;
      SQL_command(conn,"INSERT INTO confirmed_vote"
		  "(electorate_code, polling_place_code)"
		  "VALUES(%u, %u);",
		  electorate_code,0
		  );	
    }
    else { //do some sanity checking again!
      if ((!is_null_csv_pref_record(&next)) && (same_vote_csv_pref_record(&current,&next))) { 
	assert(next.pref >= current.pref);//bomb for this - sql query ORDER error should never happen
	if (next.pref == current.pref) {
	  //skip current and rest of vote
	  skip_insert = 1;
	  skip_remainder = 1;
	}
	else if (next.pref != (current.pref + 1)) {
	  //skip rest of vote
	  skip_remainder = 1;
	}
      }
      else {
	//bomb if this happens: next vote first pref is not 1 - sql query ORDER error should never happen
	assert( (next.pref == 1) || (is_null_csv_pref_record(&next)) );
      }
    }
    if (!skip_insert) {
      SQL_command(conn,"INSERT INTO confirmed_preference"
		  "(prefnum, db_candidate_index, group_index)"
		  "VALUES(%u, %u, %u);",
		  current.pref,current.ccode,current.pcode
		  );	
    }
    if (skip_remainder){//note this can only happen when next and current are the same vote
      while ((same_vote_csv_pref_record(&current,&next)) && (i < PQntuples(result)) ) { 
	get_next_csv_pref_record(result,i,&next);
	i++;
      }
    }
    copy_csv_pref_record(&next,&current);
    if (i < (PQntuples(result))){
      get_next_csv_pref_record(result,i,&next);
    }
    else {
      copy_csv_pref_record(&null_record, &next);
    }
    i++;

  }//end for loop over all csv records

  printf("Query got %u primary votes from %u ballot records\n", primary_count,PQntuples(result));
  
  PQclear(result);
}

static void load_2001_ballots(PGconn *conn)
{
  // Accessing electorates directly by code is evil but easier than writing the lookup code to get ID's 1,2,3
  // Brin = 1, Ginn = 2, Molo = 3, Test = 4
  
  //Simple Test
  load_2001_ballots_for_electorate(conn, 4, "data/test_set/tblTestBallots.txt");  
  insert_confirmed_csv_ballots(conn, 4);  

  // Brindabella Test -- NB THIS TEST DATA IS NOT COMPLETE
  //load_2001_ballots_for_electorate(conn, 1, "data/2001/tblBrinETest.txt");  
  //load_2001_ballots_for_electorate(conn, 1, "data/2001/tblBrinPTest.txt");  

  // This code preloads and then insert the CSV data from the ACT 2001 election
  // NB: See notes on input files at the top of this file.
  //load_2001_ballots_for_electorate(conn, 1, "data/2001/tblBrinElectronic.txt");  
  //load_2001_ballots_for_electorate(conn, 1, "data/2001/tblBrinPaper.txt");  
  //insert_confirmed_csv_ballots(conn, 1);
  
  //load_2001_ballots_for_electorate(conn, 2, "data/2001/tblGinnElectronic.txt");  
  //load_2001_ballots_for_electorate(conn, 2, "data/2001/tblGinnPaper.txt");  
  //insert_confirmed_csv_ballots(conn, 2);

  //load_2001_ballots_for_electorate(conn, 3, "data/2001/tblMoloElectronic.txt");  
  //load_2001_ballots_for_electorate(conn, 3, "data/2001/tblMoloPaper.txt");  
  //insert_confirmed_csv_ballots(conn, 3);  

}

static void create_csv_pref_entry_table(PGconn *conn)
{
     /*
       Create preference_summary table.

       NOTE: Ignore failure of DROP TABLE commands.
     */
  //The csv input is treated as follows:
  //fldID, -- ignore just a record count number (nonsequential too)
  //batch,pindex, -- the batch and index in the batch (assume 0 ("electronic batch") is not a legal batch # for paper votes) 
  //pref,ccode,pcode, -- the actual vote info
  //rcand -- ignore the robson rotation position
  //
  //The primary key has to be generated as we have to cope with bogus votes (e.g. doubled up preference recordings) -- darn!
  drop_table(conn,"csv_vote_entry");
  drop_table(conn,"csv_pref_entry");
  drop_sequence(conn,"csv_vote_entry_id_seq");
  //create_sequence(conn,"csv_vote_entry_id_seq");
  /*
    create_table(conn,"csv_vote_entry",
		 //"entry_id INTEGER NOT NULL PRIMARY KEY "
		 //"DEFAULT NEXTVAL('csv_vote_entry_id_seq'),"
	       "electorate_code INTEGER NOT NULL "
	       "REFERENCES electorate(code),"

	       "batch INTEGER NOT NULL,"
	       "batch_index INTEGER NOT NULL,"
	       "PRIMARY KEY (electorate_code,batch,batch_index)"
	       );
*/
  create_table(conn,"csv_pref_entry",
	       "electorate_code INTEGER NOT NULL "
	       "REFERENCES electorate(code),"

	       "batch INTEGER NOT NULL,"
	       "batch_index INTEGER NOT NULL,"

	       "pref_num INTEGER NOT NULL,"
	       "candidate_index INTEGER NOT NULL,"
	       "party_index INTEGER NOT NULL,"

	       "PRIMARY KEY (electorate_code, batch, batch_index, pref_num, candidate_index, party_index),"

	       "FOREIGN KEY(electorate_code,party_index,candidate_index)"
	       "REFERENCES candidate(electorate_code,party_index,index)"

	       //	       ",FOREIGN KEY(electorate_code,batch, batch_index)"
	       //	       "REFERENCES csv_vote_entry(electorate_code,batch, batch_index)"
	       );
}

static void create_and_load_evacs_tables(PGconn *conn)
{
  /*
    Note the create_table calls drop the table first
  */
  create_electorate_table(conn);
  create_party_table(conn);
  create_candidate_table(conn);

  create_confirmed_vote_table(conn);
  create_confirmed_preference_table(conn);

  create_csv_pref_entry_table(conn);

  load_2001_electorates(conn);
  load_2001_groups(conn);
  load_2001_candidates(conn);
  load_2001_ballots(conn);

  /*  These tables aren't used for counting...
    create_paper_table(conn);
    create_entry_table(conn);
    create_batch_table(conn);
    create_polling_place_table(conn);
    create_barcode_table(conn);
    create_server_parameter_table(conn);
    create_robson_rotation_table(conn, number_of_seats);
    create_electorate_preference_tables(conn);
  */
}

int main(int argc, char *argv[])
{
  //struct ballot_list *ballots;
  PGconn *conn;
  //struct election e;

  //drop and recreate database
  clean_database(DATABASE_NAME);  


  /* Get the information we need */
  conn = connect_db(DATABASE_NAME);
  if (conn == NULL) bailout("Can't connect to database:%s\n",
			    DATABASE_NAME);
  
  create_and_load_evacs_tables(conn);
  
  //test_routines();
  
  return 0;
}








