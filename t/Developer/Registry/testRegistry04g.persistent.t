use t::lib;
use strict;
use Test::More;
use Test::Deep;
use Class::AutoClass::Args;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use testRegistry04;

# Test Class::AutoDB::Reg
# Fetch registry stored by companion test

my $autodb=new Class::AutoDB(-database=>'test');
ok($autodb->is_connected,'Able to connect to test database');
die 'Unable to connect to database' unless $autodb->is_connected;
my $registry=$autodb->registry;
isa_ok($registry,'Class::AutoDB::Registry','registry');

# Add more classes to the registry
$registry->register
  (-class=>'testRegistry1',
   -collection=>'Collection1',-keys=>q(skey1 string));
$registry->register
  (-class=>'testRegistry2',
   -collection=>'Collection2',-keys=>q(skey2 string));

$registry->merge;
$registry->put;
ok(1,"merge and put registry with additional classes testRegistry1, testRegistry2");

done_testing();
