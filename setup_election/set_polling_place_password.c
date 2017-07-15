#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <crypt.h>
#include <common/database.h>

#define PASSWORD_LENGTH 8
#define HASH_LENGTH 13

// This program set the password_hash in the master-database table to the hash
// of a user chosen password. -1 is returned on fatal error, 1 is returned on
// non-fatal error (user failed to type two identical passwords), 0 is returned
// on success.
int main(int argc, char**argv)
{
  char password[PASSWORD_LENGTH + 1];
  char password_encrypted[HASH_LENGTH + 1];
  int i;
  char c=0;
  PGconn *conn;

  printf("Note: only the first %d characters are "
    "significant in passwords.\n\n",
    PASSWORD_LENGTH);
  printf("Enter a password to be used for end of day first preference summary generation:\n");
  // Read up to 8 characters into password
  for(i=0; i<PASSWORD_LENGTH && (c = getchar()) != '\n'; i++) {
    password[i] = c;
  }
  // Append with null
  password[i] = '\0';
  // Discard rest of line
  for (;c != '\n'; c = getchar()) {
  }

  // Encrypt the password, the extra security from implementing a random salt
  // is not needed here.
  strcpy(password_encrypted, crypt(password, "eV"));
  if (password_encrypted == NULL) {
    fprintf(stderr, "Encryption failed\n");
    return -1;
  }
  password_encrypted[HASH_LENGTH] = '\0';

  // Erase the plaintext password from memory
  for(i=0; i<PASSWORD_LENGTH + 1; i++) {
    password[i] = '\0';
  }

  // Get the password again to confirm
  printf("Confirm password:\n");
  // Read up to 8 characters into password
  for(i=0; i<PASSWORD_LENGTH && (c = getchar()) != '\n'; i++) {
    password[i] = c;
  }
  // Append with null
  password[i] = '\0';
  // Discard rest of line
  for (;c != '\n'; c = getchar()) {
  }

  // Compare the password hashes
  if (strcmp(password_encrypted, crypt(password, "eV")) != 0 ) {
    fprintf(stderr, "Passwords do no match, please try again.\n");
    return 1;
  }

  // Erase the plaintext password from memory
  for(i=0; i<PASSWORD_LENGTH + 1; i++) {
    password[i] = '\0';
  }

  // Make sure there are no ' characters in the encrypted password
  for(i=0; i<HASH_LENGTH; i++) {
    if (password_encrypted[i] == '\'') {
      password_encrypted[i] = 'a';
    }
  }

  // Put the encrypted password into the database.
  conn = connect_db("evacs");
  if (conn == NULL) {
    fprintf(stderr, "Unable to connect to database\n");
    return(-1);
  }
  SQL_command(conn,
	      "UPDATE master_data SET password_hash = '%s';",
	      password_encrypted);
  PQfinish(conn);
  
  return 0;
}    
