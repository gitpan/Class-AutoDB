use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;

# this should be the last test run. it simply removes the lock file
unlink $DBConnector::noConnectionFile if -e $DBConnector::noConnectionFile;
is(1,1); # to keep test harness happy

