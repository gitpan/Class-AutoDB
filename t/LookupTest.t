use lib 't/';
use lib 'lib/';
use Data::Dumper; ## only for testing
use strict;
use Class::AutoDB::Lookup;
use Test::More qw/no_plan/;

my $lookup = new Class::AutoDB::Lookup;

### test constructor
is(ref($lookup), "Class::AutoDB::Lookup", "calling lookup constructor");

my $string1 = "this";
my $string2 = "that";
my $obj1 = new FOO;
my $obj2 = new FOO;

### test remember
my $uid1 = $lookup->remember($string1);
my $uid2 = $lookup->remember($string2);
my $uid3 = $lookup->remember($string2); # pass by value, so preserved
my $uid4 = $lookup->remember($obj1);
my $uid5 = $lookup->remember($obj2);
my $uid6 = $lookup->remember($obj2); # pass by reference, so overwritten
isnt($uid1,$uid2, "uid's for scalars are distinct");
isnt($uid2,$uid3, "uid's for scalars are distinct given same string");
isnt($uid4,$uid5, "uid's for objects are distinct");
isnt($uid5,$uid6, "uid's for objects are distinct");

### test brainDump
my %brain_dump = $lookup->brainDump;
is(scalar keys %brain_dump, 10, "BrainDump contains correct number of entries");


### test recall
# uid -> string
is($lookup->recall($uid1), 'this', "test that get back input string");
is($lookup->recall($uid2), 'that', "test that get back input string");
is($lookup->recall($uid3), 'that', "test that get back input string");
# string -> uid
is($lookup->recall($string1), $uid1, "test that get back correct UID");
isnt($lookup->recall($string2), $uid2, "test that don't get back first UID");
is($lookup->recall($string2), $uid3, "test that get back second UID");
# test modifying scalar - 
# strings are not passed by reference, allowing Lookup to take "snapshots"
# of lists (so we may both have seperate copies of the list).
# this may not prove to be valuable, so things might change
my $string2_mod = $lookup->recall($uid2);
is($string2_mod,$string2, "test that both variables start with the same value");
$string2_mod = "somethingElse";   # modify string value
isnt($string2_mod,$string2, "test that changed copy of string");
# uid -> object
is($lookup->recall($uid4),$obj1, "test that get back correct object");
is($lookup->recall($uid5),$obj2, "test that get back correct object");
is($lookup->recall($uid6),$obj2, "test that get back correct object");
is($lookup->recall($uid5), $lookup->recall($uid6), "test that get back same object");
# object -> uid
is($lookup->recall($obj1), $uid4, "test that get back correct UID");
isnt($lookup->recall($obj2), $uid5, "test that don't get back first UID");
is($lookup->recall($obj2), $uid6, "test that get back second UID");
# test modifying object
my $obj2_mod = $lookup->recall($uid5);
is($obj2_mod,$obj2, "test that both variables point to same object");
$$obj2_mod = "bar2";   # modify object reference
is($obj2_mod,$obj2, "test that changing one ref changes underlying object");

### test brainWash
$lookup->brainWash;
%brain_dump = $lookup->brainDump;
is(scalar keys %brain_dump, 0, "BrainDump contains no entries after brainWash");
# make sure that we can still add data after a brainWashing
$lookup->remember("stuff");
%brain_dump = $lookup->brainDump;
is(scalar keys %brain_dump, 2, "Lookup still holds entries after brainWash");


### test package ###########
package FOO;

sub new {
 my $lil_foo = 'bar1';
 return bless \$lil_foo;
}

#############################

1;
