use t::lib;
use strict;
use autodbRunTests;

# driver for Class::AutoDB::Serialize tests
# runs all tests in t/Serialize
#
# argument to runtests causes testSerialize06a.multistore.t to be run
# multiple times this is needed because it tests repeated storage of
# the same objects

runtests({testcode=>1,details=>1},'testSerialize06a.multistore.t'=>3);
