use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use IO::Scalar;
use DBConnector;
use Person;
use AnotherPerson;
use Place;
use strict;

my $named_reference_object = new Class::AutoDB::Collection( -name => 'testing' );
my $nameless_reference_object = new Class::AutoDB::Collection;
my $reg1 = new Class::AutoDB::Registration(
								-class      => 'Class::Person',
								-collection => 'Person',
								-keys => qq(name string, sex string, significant_other object, friends list(object))
);
my $reg2 = new Class::AutoDB::Registration(
																						-class      => 'Class::Plant',
																						-collection => 'Flower',
																						-keys       => qq(name string, petals int, color string)
																					);
my $diff = Class::AutoDB::CollectionDiff->new( -baseline => Class::AutoDB::Collection->new($reg1),
																							 -other    => Class::AutoDB::Collection->new($reg2) );
is( ref($named_reference_object),    "Class::AutoDB::Collection" );
is( ref($nameless_reference_object), "Class::AutoDB::Collection" );
my $registration = new Class::AutoDB::Registration(
																										-class      => 'Class::Person',
																										-collection => 'Person',
																										-keys => qq(name string, favorite_song string )
																									);
$named_reference_object->register($registration);
is( $named_reference_object->_keys->{name}, "string" );
is( $named_reference_object->_keys->{favorite_song},
		"string", "register adds correct registration keys" );
is( $named_reference_object->merge("foo"), undef, "merge only accepts type collectionDiff" );
my $empty_coll1 = Class::AutoDB::Collection->new;
my $empty_coll2 = Class::AutoDB::Collection->new;
{
	my $DEBUG_BUFFER = "";
	tie *STDERR, 'IO::Scalar', \$DEBUG_BUFFER;
	my $diff =
		Class::AutoDB::CollectionDiff->new( -baseline => $empty_coll1, -other => $empty_coll2 );
	eval { $named_reference_object->merge($diff) };
	ok( $DEBUG_BUFFER =~ /merging empty collections/, "Cannot merge empty collections" );
	untie *STDERR;
}

# new keys should be merged into baseline
is( scalar keys %{ $named_reference_object->_keys }, 2 );
$named_reference_object->merge($diff);
is( scalar keys %{ $named_reference_object->_keys }, 4 );
is( $named_reference_object->keys->{petals},         "int" );
is( $named_reference_object->keys->{color},          "string" );
is( $named_reference_object->keys->{name},           "string" );
is( $named_reference_object->keys->{color},          "string" );
is(
		$named_reference_object->alter($diff)->[0],
		'alter table testing add color longtext,add petals int',
		'alter() returns expected alter statement'
	);

# now test that classes that classes are added correctly to their collections (requires a database connection)
my $DBC = new DBConnector(noclean=>0);
my $dbh = $DBC->getDBHandle;
SKIP: {
	skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again",1
		unless $DBC->can_connect;
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS
	);
	my $joe = new Person(
												-name    => 'Joe',
												-sex     => 'male',
												-alias   => 'Joe Alias',
												-hobbies => [ 'mountain climbing', 'sailing' ]
											);
	my $mary = new AnotherPerson(
																-name    => 'Mary',
																-sex     => 'female',
																-alias   => 'Mary Alias',
																-hobbies => ['hang gliding']
															);
	my $hideaway = new Place( -name => 'unamed island', -location => 'off the coast of Belize' );
	$joe->store;
	$mary->store;
	$hideaway->store;

	# retrieve Person collection from DB
	my $cursor = $autodb->find( -collection => 'Person' );
	is( $cursor->count, 2 );

	# both class Person and AnotherPerson are in collection Person
	while ( my $obj = $cursor->get_next ) {
		ok( $obj->_CLASS =~ /AnotherPerson|Person/ );
	}

	# retrieve Place collection from DB
	my $p_cursor = $autodb->find( -collection => 'Place' );
	is( $p_cursor->count, 1 );
	my $t_cursor = $autodb->find( -collection => 'Thing' );
	is( $t_cursor->count, 1 );

  # Place belongs to collections Place, Thing and has keys:
  # name string, location string, attending object, sites list(string))
	# check in-memory schema, table structure, and object's collection list
	my $place_keys = $autodb->registry->{name2coll}->{'Place'}->{_keys};
  is(scalar keys %$place_keys, 4);
  is($place_keys->{location}, 'string'); # unique to Place objects
  isnt($place_keys->{sex}, 'string'); # unique to Thing objects
	while ( my $obj = $p_cursor->get_next ) {
		ok( $obj->_CLASS =~ /Place/ );
    is($obj->__collections->[0], 'Place');
    is($obj->__collections->[1], 'Thing');
	}
	while ( my $obj = $t_cursor->get_next ) {
		ok( $obj->_CLASS =~ /Place/ );
		is($obj->__collections->[0], 'Place');
		is($obj->__collections->[1], 'Thing');
	}
}
1;
