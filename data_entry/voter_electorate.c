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

#include <string.h>
#include <stdlib.h>
#include <common/evacs.h>
#include <common/voter_electorate.h>
/*#include <common/safe.h>*/

static struct electorate *voter_electorate;


/* DDS3.2.4: Store Voter Electorate */
void store_electorate(struct electorate *electorate)
{ 
	if (voter_electorate) free(voter_electorate);
	voter_electorate = malloc(sizeof(struct electorate) 
				  + strlen(electorate->name)+1);
	voter_electorate->code = electorate->code;
	strcpy(voter_electorate->name,electorate->name);
	voter_electorate->num_seats = electorate->num_seats;
}

/* DDS3.2.6: Get Voter Electorate */
const struct electorate *get_voter_electorate(void)
{
	return voter_electorate;
}
