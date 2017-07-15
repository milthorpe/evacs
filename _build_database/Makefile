#! /usr/bin/make

# Add binaries here (each name relative to top of tree!).
BINARIES+=_build_database/create_evacs_database

# Add any extra tests to run here (each name relative to top of tree!).
EXTRATESTS+=

# Include *_test.c automatically.
CTESTS+=$(foreach tc, $(wildcard _build_database/*_test.c), $(tc:.c=))

# This needs to come before any rules, so binaries is the default.
ifndef MASTER
  binaries tests clean dep TAGS:
	$(MAKE) -C .. $@ DIR="`pwd`"
endif # MASTER

_build_database/create_evacs_database:	 common/evacs.o common/database.o common/createtables.o common/safe.o #_build_database/create_evacs_database.o
_build_database/create_evacs_database_ARGS:=-lpq 

