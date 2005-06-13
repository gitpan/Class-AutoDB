use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Registry;

# Test Class::AutoDB::Reg
# Make an empty registry and save it. Companion test fetches it.

my $autodb=new Class::AutoDB(-database=>'test');
ok($autodb->is_connected,'Able to connect to test database');
die 'Unable to connect to database' unless $autodb->is_connected;
my $registry=$autodb->registry;
isa_ok($registry,'Class::AutoDB::Registry','registry');

# now put empty registry
my $registry=new Class::AutoDB::Registry;
$registry->autodb($autodb);
$registry->merge;
$registry->put;
ok(1,"put empty registry");
