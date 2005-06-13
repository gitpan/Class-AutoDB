use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Registry;
use testRegistry04;

# Test Class::AutoDB::Reg
# Make a registry and save it. Companion test fetches it.

my $autodb=new Class::AutoDB(-database=>'test');
ok($autodb->is_connected,'Able to connect to test database');
die 'Unable to connect to database' unless $autodb->is_connected;
my $registry=$autodb->registry;
isa_ok($registry,'Class::AutoDB::Registry','registry');

# Add some content to the registry
$registry->register(-class=>'testRegistry',-collection=>'Collection1',-keys=>q(skey1 string));
$registry->register(-class=>'testRegistry',-collection=>'Collection2',-keys=>q(skey2 string));
$registry->register(-class=>'testRegistry',-collection=>'Collection3',-keys=>q(skey3 string));
$registry->register(-class=>'testRegistry',-collection=>'Collection4',-keys=>q(skey4 string));

$registry->merge;
$registry->put;
ok(1,"put registry with 4 collections");


