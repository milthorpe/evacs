#ifndef _SETUP_ELECTION_H
#define _SETUP_ELECTION_H
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

#include <libpq-fe.h>

/* Functions and definitions used by Setup Election */

/* Top level functions */
extern void store_rr(PGconn *conn);
extern void setup_batch_table(PGconn *conn);
extern void store_msg_data(const char *targetdir);
extern void store_numbers(const char *targetdir);
extern void extract_candidates(PGconn *conn);
extern void extract_elecs_and_pps(PGconn *conn);
extern void define_ballot(PGconn *conn,const char *target_dir);
extern void extract_pps(PGconn *conn);
/*extern void load_last_results(PGconn *conn);*/
#endif /*_SETUP_ELECTION_H*/
