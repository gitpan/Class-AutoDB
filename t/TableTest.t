use lib qw(. t ../lib);
use Test::More qw/no_plan/;
#use Data::Dumper; ## only for debugging
use Class::AutoDB::Table;
use DBI;
use strict;


# you must have r/w permissions for the DB that you are creating
my $reference_object = new Class::AutoDB::Table(
                                    -name=>'tree',
                                    -keys=>{height=>'integer', woodland_friends=>'string'}            
                              );


is(ref($reference_object), "Class::AutoDB::Table");

# test keys
  is($reference_object->name, "tree", "checking attributes");
  is($reference_object->keys->{height}, "integer");
  is($reference_object->keys->{woodland_friends}, "string");

# test schema
	my @results = $reference_object->schema;
	is($results[0], "create table tree (object varchar(15) not null, primary key (object),woodland_friends longtext,height int)", "testing default schema results");	

	@results = $reference_object->schema('create');
	is($results[0], "create table tree (object varchar(15) not null, primary key (object),woodland_friends longtext,height int)", "testing create schema results");	

	@results = $reference_object->schema('drop');
	is($results[0], "drop table if exists tree", "testing drop schema");	

 	my $other = "foo";
	eval{my @results = $reference_object->schema('foo', $other)};
	ok($@, "An exception if action is not recognized.");

## This is just a hack, so it tells you what you need to do to make an existing table fit in.  
# $other does nothing and is not looked for. Probably should make this smarter.
 	$other = "";
	@results = $reference_object->schema('alter', $other);
	is($results[0], "alter table tree add woodland_friends longtext,add height int", "testing alter");

