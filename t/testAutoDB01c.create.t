use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB01;
use testAutoDB01c;

# The testAutoDB series tests Class::AutoDB::AutoDN

# tests start here
my $testname="from scratch: 1 collection, 1 scalar key, 1 list key: create=>1";
my $tables=[qw(Collection)];

start($testname,$tables);
my $autodb=new Class::AutoDB(-database=>'test',-create=>1);
test_create($testname,$tables);

