use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB02;
use testAutoDB01d;

# The testAutoDB series tests Class::AutoDB::AutoDB

# tests start here
my $testname="1 collection, 2 scalar keys, 2 list keys: create=>1";
my $tables=[qw(Collection)];

my $autodb=new Class::AutoDB(-database=>'test',-create=>1);
test_create($testname,$tables);

