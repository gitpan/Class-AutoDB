use t::lib;
use strict;
use autodbRunTests;

# driver for Class::AutoDB::Collection tests
# runs all tests in t/Collection. 
runtests {testcode=>1,details=>1};
