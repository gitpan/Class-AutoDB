use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use strict;

my $reference_object = new Class::AutoDB::Registration
                                  (-class=>'Class::Person',
                                   -collection=>'Person',
                                   -keys=>qq(name string, sex string, significant_other object, 
                                    insignificant_others object, friends list(object)),
                                   -skip=>[qw(age)],
                                   -auto_get=>[qw(significant_other insignificant_others)]);



is(ref($reference_object), "Class::AutoDB::Registration");

# validate collection
my $collection=$reference_object->collection;
is($collection,"Person", "valid collection");
# validate class
my $class=$reference_object->class;
is($class,"Class::Person", "valid class");
# validate keys
my $keys=$reference_object->keys;
is($keys->{name},"string", "testing keys");
is($keys->{sex},"string");
is($keys->{significant_other},"object");
is($keys->{insignificant_others},"object");
is($keys->{friends},"list(object)");
is($keys->{not_there}, undef);
# auto_get
my $auto_get=$reference_object->auto_get;
is($auto_get->[0],"significant_other", "testing auto_get");
is($auto_get->[1],"insignificant_others");
# skip
my $skip=$reference_object->skip;
is($skip->[0],"age", "testing skip");

