use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB02;
use testAutoDB01cc;

# The testAutoDB series tests Class::AutoDB::AutoDB

# tests start here
my $testname="2 collections, 1 scalar key, 1 list key: default schema ops";
my $tables=[qw(Collection1 Collection2)];

eval {
  my $autodb=new Class::AutoDB(-database=>'test');
};
ok($@=~ /Some collections are expanded/i,"$testname: inconsistent changes");

