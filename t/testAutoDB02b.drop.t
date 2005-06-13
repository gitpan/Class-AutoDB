use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB02;
use testAutoDB01b;

# The testAutoDB series tests Class::AutoDB::AutoDB

# tests start here
my $testname="1 collection, 1 scalar key: drop=>1";
my $tables=[qw(Collection)];

my $autodb=new Class::AutoDB(-database=>'test',-drop=>1);
test_drop($testname,$tables);

