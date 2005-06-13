use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use testAutoDB02;
use testAutoDB01d;

# The testAutoDB series tests Class::AutoDB::AutoDB

# tests start here
my $testname="1 collection, 2 scalar keys, 2 list keys: default schema ops";
my $tables=[qw(Collection)];

eval {
  my $autodb=new Class::AutoDB(-database=>'test');
};
ok($@=~ /Some collections are expanded/i,"$testname: inconsistent changes");
