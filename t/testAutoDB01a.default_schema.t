use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB01;
use testAutoDB01a;

# The testAutoDB series tests Class::AutoDB::AutoDN

# tests start here
my $testname="from scratch: empty schema: default schema ops";
my $tables=[];

start($testname,$tables);
my $autodb=new Class::AutoDB(-database=>'test');
test_create($testname,$tables);

