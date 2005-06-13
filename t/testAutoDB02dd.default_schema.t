use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB02;
use testAutoDB01dd;

# The testAutoDB series tests Class::AutoDB::AutoDB

# tests start here
my $testname="2 collections, 2 scalar keys, 2 list keys: default schema ops";
my $tables=[qw(Collection1 Collection2)];

eval {
  my $autodb=new Class::AutoDB(-database=>'test');
};
ok($@=~ /Some collections are expanded/i,"$testname: inconsistent changes");

