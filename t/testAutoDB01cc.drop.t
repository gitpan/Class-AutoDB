use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB01;
use testAutoDB01cc;

# The testAutoDB series tests Class::AutoDB::AutoDN

# tests start here
my $testname="from scratch: 2 collections, 1 scalar key, 1 list key: drop=>1";
my $tables=[qw(Collection1 Collection2)];

start($testname,$tables);
my $autodb=new Class::AutoDB(-database=>'test',-drop=>1);
test_drop($testname,$tables);

