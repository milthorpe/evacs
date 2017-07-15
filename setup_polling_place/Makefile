#! /usr/bin/make

# Add binaries here (each name relative to top of tree!).
# SIPL 2011-09-21 Removed ppname_to_code, initialise_db.
BINARIES+=setup_polling_place/hash_barcode

# Add any extra tests to run here (each name relative to top of tree!).

EXTRATESTS+=setup_polling_place/ppname_to_code_test.sh

# Include *_test.c automatically.
CTESTS+=$(foreach tc, $(wildcard setup_polling_place/*_test.c), $(tc:.c=))

# This needs to come before any rules, so binaries is the default.
ifndef MASTER
  binaries:
	$(MAKE) -C .. binaries DIR="`pwd`"
  tests:
	$(MAKE) -C .. tests DIR="`pwd`"
  clean:
	$(MAKE) -C .. clean DIR="`pwd`"
endif # MASTER

# To make the binary, you need to link this in as well as the .c file.
setup_polling_place/ppname_to_code: common/evacs.o common/database.o
setup_polling_place/initialise_db: common/evacs.o common/database.o common/createtables.o
setup_polling_place/hash_barcode: common/barcode_hash.o common/barcode.o common/evacs.o

# Test example needs these to run:
setup_polling_place/ppname_to_code_test: common/evacs.o common/database.o
setup_polling_place/initialise_db_test: common/evacs.o common/database.o common/createtables.o
setup_polling_place/ppname_to_code_ARGS:=-lpq
setup_polling_place/initialise_db_ARGS:=-lpq
setup_polling_place/hash_barcode_ARGS:=-lcrypto
setup_polling_place/initialise_db_test_ARGS:=-lpq

setup_polling_place/ppname_to_code_test.sh-run:=setup_polling_place/ppname_to_code_test setup_polling_place/ppname_to_code
setup_polling_place/initialise_db_test.sh-run:=setup_polling_place/initialise_db_test setup_polling_place/initialise_db
setup_polling_place/setup_pp_test.sh-run:=setup_polling_place/setup_pp_test
