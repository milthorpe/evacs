#! /usr/bin/make

# Add binaries here (each name relative to top of tree!).
# SIPL 2011-09-21 Removed setup_bin.
BINARIES+=setup_election/gen_barcodes_bin
BINARIES+=setup_election/check_central_scrutiny_bin
BINARIES+=setup_election/set_polling_place_password
BINARIES+=setup_election/set_date_time_password

# Add any extra tests to run here (each name relative to top of tree!).
EXTRATESTS+=setup_election/define_ballot_test.sh
EXTRATESTS+=setup_election/extract_pps_test.sh
EXTRATESTS+=setup_election/setup_batch_table_test.sh
EXTRATESTS+=setup_election/store_msg_data_test.sh
EXTRATESTS+=setup_election/store_numbers_test.sh
EXTRATESTS+=setup_election/store_rr_test.sh
EXTRATESTS+=setup_election/draw_barcode_test.sh
EXTRATESTS+=setup_election/gen_barcodes_test.sh
EXTRATESTS+=setup_election/load_last_results_test.sh

# Include *_test.c automatically.
CTESTS+=$(foreach tc, $(wildcard setup_election/*_test.c), $(tc:.c=))

# This needs to come before any rules, so binaries is the default.
ifndef MASTER
  binaries tests clean dep TAGS:
	$(MAKE) -C .. $@ DIR="`pwd`"
endif # MASTER

setup_election/setup_bin: setup_election/stores.o common/evacs.o common/database.o common/createtables.o  
setup_election/check_central_scrutiny_bin: common/evacs.o common/database.o common/batch.o common/find_errors.o
setup_election/gen_barcodes_bin: setup_election/gen_barcodes.o setup_election/draw_barcode.o common/barcode.o common/barcode_hash.o common/evacs.o common/database.o
setup_election/stores: common/evacs.o common/database.o common/createtables.o   
setup_election/set_polling_place_password: setup_election/set_polling_place_password.o common/database.o common/evacs.o
setup_election/set_date_time_password: setup_election/set_date_time_password.o common/database.o common/evacs.o
setup_election/extract_pps_test: common/evacs.o common/database.o  common/createtables.o
setup_election/load_last_results_test: common/evacs.o common/database.o  common/createtables.o
setup_election/define_ballot_test: common/evacs.o common/database.o common/createtables.o 
setup_election/store_msg_data_test: common/evacs.o common/database.o common/createtables.o 
setup_election/store_numbers_test: common/evacs.o common/database.o common/createtables.o 
setup_election/setup_batch_table_test: common/evacs.o common/database.o common/createtables.o 
setup_election/store_rr_test: common/evacs.o common/database.o common/createtables.o 
# Needs crypto library for SHA routine.
setup_election/check_central_scrutiny_bin_ARGS:=-lpq
setup_election/setup_bin_ARGS:=-lpq
setup_election/set_polling_place_password_ARGS:= -lpq -lcrypt
setup_election/set_date_time_password_ARGS:= -lpq -lcrypt
setup_election/gen_barcodes_bin_ARGS:= -lbarcode -lcrypto -lpq
setup_election/extract_pps_test_ARGS:=-lpq
setup_election/load_last_results_test_ARGS:=-lpq
setup_election/define_ballot_test_ARGS:=-lpq
setup_election/store_msg_data_test_ARGS:=-lpq
setup_election/store_rr_test_ARGS:=-lpq
setup_election/setup_batch_table_test_ARGS:=-lpq
setup_election/store_numbers_test_ARGS:=-lpq
setup_election/gen_barcodes_ARGS:=-lbarcode
setup_election/draw_barcode_test: common/barcode.o common/evacs.o 
setup_election/draw_barcode: common/barcode.o common/evacs.o 
setup_election/gen_barcodes: setup_election/draw_barcode.o common/barcode.o common/evacs.o  common/database.o common/barcode_hash.o
setup_election/gen_barcodes_test: setup_election/draw_barcode.o common/barcode.o common/evacs.o  common/database.o common/createtables.o common/barcode_hash.o
setup_election/draw_barcode_test_ARGS:=-lbarcode -lcrypto
setup_election/gen_barcodes_test_ARGS:=-lbarcode -lcrypto -lpq
# Need draw_barcode_test to run draw_barcode_test.sh.
setup_election/draw_barcode_test.sh-run: setup_election/draw_barcode_test
setup_election/define_ballot_test.sh-run: setup_election/define_ballot_test
setup_election/extract_pps_test.sh-run: setup_election/extract_pps_test
setup_election/setup_batch_table_test.sh-run: setup_election/setup_batch_table_test
setup_election/store_msg_data_test.sh-run: setup_election/store_msg_data_test
setup_election/store_numbers_test.sh-run: setup_election/store_numbers_test
setup_election/store_rr_test.sh-run: setup_election/store_rr_test

setup_election/gen_barcodes_test.sh-run: setup_election/gen_barcodes_test
