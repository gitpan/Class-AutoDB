use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB02;
use testAutoDB01dd;

# The testAutoDB series tests Class::AutoDB::AutoDB

# tests start here
my $testname="2 collections, 2 scalar keys, 2 list keys: alter=>1";
my $tables=[qw(Collection1 Collection2)];

my $autodb=new Class::AutoDB(-database=>'test',-alter=>1);
test_alter($testname,$tables);

