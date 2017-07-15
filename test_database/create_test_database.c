/* This file is (C) copyright 2005 NICTA, Pty Ltd */

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

/*
  NOTES ON CSV DATA 

 The electorates, groups and candidates are all from single files.  The
 ballot information is supplied per electorate and processed as such.
  
 It is assumed that all lines in the csv file contain valid records, except
 the first line, which contains the field names.  

*/ 

const char* electorates_csv_file = "Electorates.txt";
const char* groups_csv_file      = "Groups.txt";  
const char* candidates_csv_file  = "Candidates.txt";   
const char* csv_files_path;//[1024];


/*! Get the next token from the comma separated (CSV) stream 
    @Pre there must be a valid token
*/ 

/* Modified by AT to take into account quoted texts -- 03 Jun 09 */
static char* get_csv_token(FILE* csvfile, char* token){

  int index = 0;
  int inchar;
  bool endtoken = false;
  bool inquotes = false;

  inchar = fgetc(csvfile);


  while ( !endtoken && (inchar != '\n') && (!feof(csvfile)) ){
    if (inchar == ',' && !inquotes) endtoken = true;

    /* Skip over the <CR> for a DOS EOL */
    else if (inchar == '\r'){
      inchar = fgetc(csvfile);
    }

    else if (inchar == '\"') {
      if (inquotes) inquotes = false;
      else inquotes = true;
      inchar = fgetc(csvfile);
    }
    else { 
      /* Cope with ' in names etc by doubling them */
      if (inchar == '\''){
	token[index++] = '\'';
      }
      token[index++] = inchar;
      inchar = fgetc(csvfile);
    }
  }
  token[index] = (char)NULL;
  //printf("Token read: %s\n", token);

  return token;
}

/* 
   Skip the rest of the current CSV record (read to EOL)
*/
static void ignore_rest_of_csv_record(FILE* csvfile){
  int inchar;
  inchar = fgetc(csvfile);
  while ((inchar != '\n') && (!feof(csvfile)) ){
    inchar = fgetc(csvfile);
  }
}


static FILE* fopen_csv_file(const char *csv_file_name)
{
  FILE *f;
  char *path_and_name;
  int inchar;

  path_and_name = malloc(sizeof(char)*(strlen(csv_file_name)+strlen(csv_files_path)+1));

  strcpy(path_and_name,csv_files_path);
  strcat(path_and_name,csv_file_name);
  
  f = fopen(path_and_name,"r");
  if (f == NULL)bailout("Can't open file:%s\n",path_and_name);

  /* strip first line */
  inchar = fgetc(f);
  //printf("%c",inchar);
  while ((inchar != '\n') && (!feof(f)) ){
    inchar = fgetc(f);
    //printf("%c",inchar);
  }

  return f;
}

/* 
   [AT 03 Jun 09] Description from Electorates.txt:

"ecode", "electorate"
INTEGER, TEXT

The values for the fields seat_count, number_of_electors and colour
are not included in the csv file, so are omitted here.

 */

static void load_electorates(PGconn *conn)
{
  char buff[512];
  int record_count = 0;

  int  ecode = 0;
  char name[255];
  int  num_electors = 0;

  FILE* f = fopen_csv_file(electorates_csv_file);

  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      ecode = atoi(buff);
      strcpy(name,get_csv_token(f,buff));
      get_csv_token(f,buff);
      num_electors = atoi(buff);
      
      /* seat_count = atoi(get_csv_token(f,buff));
	 strcpy(colour, get_csv_token(f,buff)); */
      record_count++;
      /* SQL_command(conn,"INSERT INTO electorate"
		  "(code, name, seat_count, number_of_electors,colour) "
		  "VALUES(%u,'%s', %u, %u, '%s');",
		  ecode,name,seat_count,num_electors,colour
		  ); */

      SQL_command(conn,"INSERT INTO electorate"
		  "(code, name, seat_count) "
		  "VALUES(%u,'%s',%u);",
		  ecode,name,num_electors
	);
    }    
  }
  printf("Loaded %d electorates.\n",record_count);
  fclose(f);
}

/* 
[AT 03 Jun 09]
Description for Groups.txt: 

"ecode","pcode","pname","pabbrev","cands"
INTEGER, INTEGER, TEXT, TEXT, INTEGER

"cands" is not used apparently. 

*/

static void load_groups(PGconn *conn)
{
  char buff[512];
  int  record_count = 0;

  int  index = 0;
  int  ecode = 0;
  int  pcode = 0;
  char name[255];
  char abbrev[255];
  int num_cands = 0;

  FILE* f = fopen_csv_file(groups_csv_file);

  while (!feof(f)){
    get_csv_token(f,buff);

    if (buff[0]!= (char)NULL){
      /* index = atoi(buff); */
      ecode = atoi(buff); 
      /* ecode = atoi(get_csv_token(f,buff)); */
      pcode = atoi(get_csv_token(f,buff));
      strcpy(name,get_csv_token(f,buff));
      strcpy(abbrev,get_csv_token(f,buff));
      num_cands = atoi(get_csv_token(f,buff));
      record_count++;      
      SQL_command(conn,"INSERT INTO party"
		  "(electorate_code, index, name, abbreviation) "
		  "VALUES(%u, %u, '%s', '%s');",
		  ecode, pcode, name,abbrev
	);
    }    
  }
  printf("Loaded %d groups (parties).\n",record_count);
  fclose(f);
}

/* 
[AT 03 Jun 09]
Description for Candidates.txt:

"ecode","pcode","ccode","cname"
INTEGER, INTEGER, INTEGER, TEXT

*/

static void load_candidates(PGconn *conn)
{
  char buff[512];
  int record_count = 0;

  int  index = 0;
  int  ecode = 0;
  int  pcode = 0;
  int  ccode = 0;
  char name[255];

  FILE* f = fopen_csv_file(candidates_csv_file);

  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      /* index = atoi(buff); */
      ecode = atoi(buff);
      /* ecode = atoi(get_csv_token(f,buff)); */
      pcode = atoi(get_csv_token(f,buff));
      ccode = atoi(get_csv_token(f,buff));
      strcpy(name,get_csv_token(f,buff));
      /*ignore_rest_of_csv_record(f);*/

      record_count++;      
      SQL_command(conn,"INSERT INTO candidate"
		  "(electorate_code, party_index, index, name) "
		  "VALUES(%u, %u, %u, '%s');",
		  ecode,pcode,ccode,name
	);
    }    
  }
  printf("Loaded %d candidates.\n",record_count);
  fclose(f);
}

static void load_ballots_for_electorate(PGconn *conn, int electorate_code, const char *filename)
{
  
  char buff[512];
  int  record_count = 0;
  int  primary_count = 0;

  int  batch = 0;
  int  bindex = 0;
  int  pref = 0;
  int  ccode = 0;
  int  pcode = 0;
  int  rcand = 0;

  FILE* f = fopen_csv_file(filename);

  printf("Loading Electorate(%u)",electorate_code);  fflush(stdout);
  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      //batch,pindex,pref,pcode,ccode,rcand
      batch  = atoi(buff);
      bindex = atoi(get_csv_token(f,buff));
      pref   = atoi(get_csv_token(f,buff));
      pcode  = atoi(get_csv_token(f,buff));
      ccode  = atoi(get_csv_token(f,buff));
      rcand  = atoi(get_csv_token(f,buff));

      if (pref == 1) {
	primary_count++;
	if ((primary_count % 1000) == 0)
	  printf(".");fflush(stdout);
      }

      record_count++;
            
      SQL_command(conn,"INSERT INTO csv_pref_entry"
		  "(electorate_code, batch, batch_index,"
		  " pref_num, candidate_index, party_index)"
		  "VALUES(%u, %u, %u, %u, %u, %u);",
		  electorate_code,batch,bindex,pref,ccode,pcode
		  );
      
    }
  }//endwhile
  printf("\n");
  printf("Loaded %d primary votes and a total of %d preference records from file %s.\n",primary_count,record_count, filename);
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

static void get_csv_pref_record(PGresult *result, int record_num, csv_pref_record *record)
{
  if (record_num < (PQntuples(result))){
    record->ecode  = atoi(PQgetvalue(result, record_num, 0));
    record->batch  = atoi(PQgetvalue(result, record_num, 1));
    record->bindex = atoi(PQgetvalue(result, record_num, 2));
    record->pref   = atoi(PQgetvalue(result, record_num, 3));
    record->pcode  = atoi(PQgetvalue(result, record_num, 4));
    record->ccode  = atoi(PQgetvalue(result, record_num, 5));
    record->is_null_record = 0;
  }
  else {
    set_null_csv_pref_record(record);
  }
}

static void copy_csv_pref_record(csv_pref_record *src,csv_pref_record *dest)
{
  dest->ecode  =   src->ecode;
  dest->batch  =   src->batch; 
  dest->bindex =   src->bindex; 
  dest->pref   =   src->pref; 
  dest->pcode  =   src->pcode;
  dest->ccode  =   src->ccode; 
  dest->is_null_record = src->is_null_record; 
}

static int next_record_is_same_vote(PGresult *result, int record_num)
{
  csv_pref_record x,y;

  get_csv_pref_record(result, record_num, &x);
  get_csv_pref_record(result, record_num+1, &y);

  if (is_null_csv_pref_record(&x) || is_null_csv_pref_record(&y))
    return 0;
  else
    return(   (x.ecode == y.ecode) 
	      && (x.batch == y.batch) 
	      && (x.bindex == y.bindex)
	      );
}

static char* get_csv_pref_string(PGresult *result, int *record_num)
{
  /* 
     Pre: record_num is the first preference of a vote.

     There are two cases for a vote to be partially discarded: (1) It
     contains a duplicate preference number whose value is greater than 1, or
     (2) It contains a non-contiguous sequence of preference numbers
     
     Solutions: (1) The duplicate preference entries and all following
     (greater in value) preferences are discarded (2) All preference entries
     after the gap are discarded
     
     Assume record at record_num is a primary preference, and is part of a
     formal vote.  The records are in order of preferences.
  */
  #define DIGITS_PER_PREF 6
  char pref_string[PREFNUM_MAX * DIGITS_PER_PREF];
  char *return_string, *pref_ptr;
  int last_pref = 0;
  int disregard_remainder = 0;
  csv_pref_record record;

  do {
    get_csv_pref_record(result, *record_num, &record);
    /* Is this preference 1 greater than the last given? */
    if ((last_pref+1) != record.pref){
      disregard_remainder = 1;
    }
    /* Is there a next preference with the same number? */
    /* Note we assume the informal case of 2 "1"'s has already been checked. */
    if (next_record_is_same_vote(result, (*record_num))){
      csv_pref_record next_record;
      get_csv_pref_record(result, (*record_num+1), &next_record);
      if (record.pref == next_record.pref){
	assert(next_record.pref != 1);
	disregard_remainder = 1;
      }
    }

    if (!disregard_remainder){
      pref_ptr=&pref_string[0]+sizeof(char)*((last_pref)*DIGITS_PER_PREF);
      sprintf(pref_ptr,"%02u%02u%02u",
	      record.pref,record.pcode,record.ccode);
      last_pref++;
    }
  }while(next_record_is_same_vote(result, (*record_num)++));

  return_string = malloc(sizeof(char) * (strlen(pref_string) + 1));
  strcpy(return_string,pref_string);  
  return return_string;
}


/*
  Assumes no informals.

*/
static void insert_confirmed_csv_ballots(PGconn *conn, int electorate_code)
{
  PGresult *result_electorate_name;
  PGresult *result;
  int record_count=0;
  int primary_count = 0;

  result_electorate_name = SQL_query(conn,
		     "SELECT name "
		     "FROM electorate "
		     "WHERE code = %u "
		     ,electorate_code
		     );
  assert(PQntuples(result_electorate_name) == 1);

  result = SQL_query(conn,
		     "SELECT * "
		     "FROM csv_pref_entry "
		     "WHERE electorate_code = %u "
		     "ORDER BY electorate_code, batch, batch_index, "
		     "pref_num, candidate_index, party_index"
		     ,electorate_code
		     );

  printf("Found %u preferences for electorate %u\n", PQntuples(result), electorate_code);

  while (record_count < PQntuples(result)){
    char *pref_string;
    /* INFORMAL VOTE CHECKING */
    csv_pref_record pref_record;
    get_csv_pref_record(result,record_count,&pref_record); 
    /* The first record MUST be 1 to be formal*/
    assert(pref_record.pref == 1);
    /* If the following record is part of the same vote, then the preference
       given MUST NOT be 1 for the vote to be to be formal*/
    if (next_record_is_same_vote(result, record_count)) {
      get_csv_pref_record(result,record_count+1,&pref_record); 
      assert(pref_record.pref != 1);
    }

    /* READ AND LOAD THE VOTE */
    pref_string = get_csv_pref_string(result,&record_count);
    SQL_command(conn,
		"INSERT INTO confirmed_vote"
		"(electorate_code, polling_place_code) "
		"VALUES(%u,%u);",
		electorate_code,
		0);
    free(pref_string);
    ++primary_count;
  }

  printf("Confirmed %u primary prefs from %u pref records.\n",
	 primary_count,PQntuples(result));
  
  PQclear(result);
  PQclear(result_electorate_name);
}



static void create_csv_batch_pp_table(PGconn *conn)
{

  drop_table(conn,"csv_batch_pp_entry");

  create_table(conn,"csv_batch_pp_entry",
	       "ppn INTEGER NOT NULL, "
	       "batch_number INTEGER NOT NULL,"
	       "pollingplace TEXT NOT NULL," 
	       "PRIMARY KEY (ppn, batch_number, pollingplace)"
	       );


}

static void load_csv_batch_pp_entry(PGconn *conn, const char *filename)
{
  
  char buff[512];
  int  record_count = 0;
  int  batch = 0;
  int  ppn = 0;
  char pollingplace[512] = "";

  FILE* f = fopen_csv_file(filename);

  printf("Loading polling place and batch numbers");  fflush(stdout);
  while (!feof(f)){
    get_csv_token(f,buff);
    if (buff[0]!= (char)NULL){
      ppn  = atoi(buff);
      batch = atoi(get_csv_token(f,buff));
      strcpy(pollingplace, get_csv_token(f,buff));

      record_count++;
            
      SQL_command(conn,"INSERT INTO csv_batch_pp_entry"
		  "(ppn, batch_number, pollingplace)"
		  "VALUES(%u, %u, '%s');",
		  ppn, batch, pollingplace
		  );
      
    }
  }//endwhile
  printf("\n");
  printf("Loaded %d records from file %s.\n", record_count, filename);
}

static void load_polling_place_and_batch(PGconn *conn)
{
  load_csv_batch_pp_entry(conn, "PollingPlaceBatchNumbers.txt");

  /* Insert into polling place table */

  printf("Inserting entries into polling_place table ...");
  SQL_command(conn,
		"INSERT INTO polling_place (code, name) "
		"SELECT DISTINCT ON (ppn, pollingplace) ppn, pollingplace "
  	        "FROM csv_batch_pp_entry;");
  printf("done.\n");

  printf("Inserting entries into batch table ...");
  SQL_command(conn,
	      "INSERT INTO batch (number, polling_place_code, electorate_code) "
	      "SELECT DISTINCT ON (batch, ppn, electorate_code) batch, ppn, electorate_code "
	      "FROM csv_pref_entry, csv_batch_pp_entry WHERE batch = batch_number;");
  printf("done.\n");

}

/*
[AT 03 Jun 09]
Changed the names of the text files to conform with the ones used
by the ACT Electoral Comission. There's no separate paper version. Both 
paper and electronic versions are given in a single file.

BrindabellaTotal.txt 
GinninderraTotal.txt
MolongloTotal.txt

 */
static void load_act_ballots(PGconn *conn)
{
  /*
    Loading electorate data is hard wired since the input data specifies the
    electorate by the name of the file.
    The (fixed) index codes as defined in the data 'electorates.txt' are
    Brindabella = 1, Ginninderra = 2, Kurrajong = 3, 
    Murrumbidgee = 4, Yerrabi = 5, Test = 6
  */


  //load_ballots_for_electorate(conn, 1, "BrindabellaTotal.txt");  
  //load_ballots_for_electorate(conn, 2, "GinninderraTotal.txt");  
  //load_ballots_for_electorate(conn, 3, "KurrajongTotal.txt");  
  //load_ballots_for_electorate(conn, 4, "MurrumbidgeeTotal.txt");  
  //load_ballots_for_electorate(conn, 5, "YerrabiTotal.txt");  

  /* load_csv_batch_pp_entry(conn, "PollingPlaceBatchNumbers.txt"); */
  //load_polling_place_and_batch(conn); 
  
  insert_confirmed_csv_ballots(conn, 1);  
  insert_confirmed_csv_ballots(conn, 2);
  insert_confirmed_csv_ballots(conn, 3);  
  insert_confirmed_csv_ballots(conn, 4);
  insert_confirmed_csv_ballots(conn, 5);  

}

static void load_test_ballots(PGconn *conn)
{
  load_ballots_for_electorate(conn, 6, "tblTestPaper.txt");  
  insert_confirmed_csv_ballots(conn, 6);  
}


static void create_csv_pref_entry_table(PGconn *conn)
{
  /*
    Create csv_pref_entry table.
    
    NOTE: Ignore failure of DROP TABLE commands.
  
  
    The primary key has to be generated as we have to cope with bogus votes
    (e.g. doubled up preference recordings) -- darn!

  */

  drop_table(conn,"csv_pref_entry");

  create_table(conn,"csv_pref_entry",
	       "electorate_code INTEGER NOT NULL "
	       "REFERENCES electorate(code),"

	       "batch INTEGER NOT NULL,"
	       "batch_index INTEGER NOT NULL,"

	       "pref_num INTEGER NOT NULL,"
	       "party_index INTEGER NOT NULL,"
	       "candidate_index INTEGER NOT NULL,"

	       "PRIMARY KEY (electorate_code, batch, batch_index, "
	       "pref_num, party_index, candidate_index ),"

	       "FOREIGN KEY(electorate_code,party_index,candidate_index)"
	       "REFERENCES candidate(electorate_code,party_index,index)"
	       );

  /*
  PGresult *result_electorate_name;
  PGresult *result;
  int record_count=0;
  int primary_count = 0;

  result_electorate_name = SQL_query(conn,
		     "SELECT name "
		     "FROM electorate "
		     "WHERE code = %u "
		     ,electorate_code


CREATE TABLE "molonglo_confirmed_vote" (
        "id" integer,
        "batch_number" integer,
        "paper_version" integer,
        "time_stamp" text,
        "preference_list" text
);

		     );


  assert(PQntuples(result_electorate_name) == 1);
  */


}

static void create_and_load_evacs_tables(PGconn *conn)
{
  /*
    NOTE: the create_table calls drop the table first
  */
  //create_electorate_table(conn);
  //create_party_table(conn);
  //create_candidate_table(conn);
  //create_csv_pref_entry_table(conn);



  /*
    NOTE: The electorates defn has to be loaded before the confirmed vote
    tables are created.
  */
  //load_electorates(conn);

  //create_polling_place_table(conn);
  //create_batch_table(conn); 
  //create_confirmed_vote_table(conn);
  //create_csv_batch_pp_table(conn);




  //load_groups(conn);
  //load_candidates(conn);
  load_act_ballots(conn); 


  //load_test_ballots(conn);

  /*  These tables aren't used for counting...

      create_polling_place_table(conn);
      create_batch_table(conn);

    create_paper_table(conn);
    create_entry_table(conn);
    create_barcode_table(conn);
    create_server_parameter_table(conn);
    create_robson_rotation_table(conn, number_of_seats);
    create_electorate_preference_tables(conn);
  */



}


/*
  First time creation of a database.
*/
static PGconn *create_first_time_database(const char *name)
{
  PGconn *conn=NULL;
  
  conn = connect_db("template1");
  if (conn == NULL) bailout("Can't connect to database: template1\n");
  SQL_command(conn, "CREATE DATABASE %s;", name);
  PQfinish(conn);
  printf("Created initial %s database.\n", DATABASE_NAME);
  return connect_db(name);
}

int main(int argc, char *argv[])
{
  PGconn *conn=NULL;
  const char *null_path = "";

  printf("Start:  Database is %s\n", DATABASE_NAME);

  //conn = create_first_time_database(DATABASE_NAME);  
  //exit(0);

  if (argc == 1) {
    csv_files_path = null_path;
    printf("Using csv files from local dir\n");
  }
  else if (argc >= 2) {
    csv_files_path = argv[1];
    printf("Using csv files from %s\n",csv_files_path);
  }

  /* Drop and recreate database */
  //clean_database(DATABASE_NAME);  

  printf("Connecting to database %s\n", DATABASE_NAME);
  conn = connect_db(DATABASE_NAME);
  if (conn == NULL) bailout("Can't connect to database:%s\n",
			    DATABASE_NAME);
  
  create_and_load_evacs_tables(conn);
  
  //test_routines();
  
  return 0;
}








