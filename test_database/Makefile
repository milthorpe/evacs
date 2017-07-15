#! /usr/bin/make

# Add binaries here (each name relative to top of tree!).
BINARIES+=test_database/create_test_database

# Add any extra tests to run here (each name relative to top of tree!).
EXTRATESTS+=

# Include *_test.c automatically.
CTESTS+=$(foreach tc, $(wildcard test_database/*_test.c), $(tc:.c=))

# This needs to come before any rules, so binaries is the default.
ifndef MASTER
  binaries tests clean dep TAGS:
	$(MAKE) -C .. $@ DIR="`pwd`"
endif # MASTER

test_database/create_test_database:	 common/evacs.o common/database.o common/createtables.o common/safe.o #test_database/create_test_database.o
test_database/create_test_database_ARGS:=-lpq 

