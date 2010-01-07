use t::lib;
use strict;
use autodbRunTests;

# driver for Class::AutoDB::Registration tests
# runs all tests in t/Registration. 
runtests {testcode=>1,details=>1};
