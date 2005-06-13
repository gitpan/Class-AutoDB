use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB01;
use testAutoDB01ee;

# The testAutoDB series tests Class::AutoDB::AutoDN

# tests start here
my $testname="from scratch: 2 collections, scalar and list keys of all types: default schema ops";
my $tables=[qw(Collection1 Collection2)];

start($testname,$tables);
my $autodb=new Class::AutoDB(-database=>'test');
test_create($testname,$tables);

