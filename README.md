# Unofficial fork of the ACT Electronic Voting and Counting System (eVACS)

This is a modified version of the [Australian Capital Territory's Electronic Voting and Counting System, eVACS](http://www.elections.act.gov.au/elections_and_voting/electronic_voting_and_counting).
This project was modified from the 2016 version of the system, developed by Software Improvements, Inc. and available from the ACT Electoral Commission Website.

A module `test_database` has been added which allows the `evacs` postgresql database to be created and loaded from [ballot paper data files provided by the ACT electoral commission](http://www.elections.act.gov.au/elections_and_voting/past_act_legislative_assembly_elections/2016-election/ballot-paper-preference-data-2016-election).
This module is based on code developed by Alwen Tiu, Michael Norrish and others at NICTA and the Australian National University.

The 2016 version of the software available from the electoral commission can only be built with an outdated version of GCC (<=4.1).
Several changes have been made in this version to allow the software to be built on current platforms:

- replace hand-rolled memory management routines for formatted reading and writing (`fgets_malloc`, `sprintf_malloc`, `vsprintf_malloc`) with standard routines from glibc and glib
- correct pointer size for 64-bit architectures
- replace custom `poster` program with standard GNU/Linux version
