use lib qw(. t ../lib);
use strict;
use TestAutoDB_1;
use DBConnector;
use Class::AutoDB;
use Class::AutoClass::Args;
use Class::AutoDB::Cursor;
use Scalar::Util;
use Test::More qw/no_plan/;
my $DBC = new DBConnector();
my $dbh = $DBC->getDBHandle;
SKIP: {
	skip
"! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again",
		1
		unless $DBC->can_connect;
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS
	);

	# populate the collection
	for ( 1 .. 10 ) {
		TestAutoDB_1->new( -this => $_, -that => 'thingy' . $_ )->store;
	}

	# grab the whole collection
	my $cursor = $autodb->find( -collection => 'TestAutoDB_1' );
	is( ref($cursor), "Class::AutoDB::Cursor",
			"calling find() as a method on an AutoDB object returns a Cursor object" );
	is( scalar $cursor->get, 10, "10 collections are currently registered" );

	# test the Cursor's count
	is( $cursor->count, 10 );

	# grab a subset (target) from the collection
	$cursor = $autodb->find( -collection => 'TestAutoDB_1', -that => 'thingy5' );
	is( $cursor->count, 1, "one collection matches the query" );
	my ($thingy5) = $cursor->get;
	is( ref($cursor), "Class::AutoDB::Cursor" );
	is( $thingy5->that, 'thingy5' );

	# get_next: iterator for returned collections
	for ( 4 .. 6 ) {
		TestAutoDB_1->new( -this => $_, -that => 'things', -other => ['other_things'] )->store;
	}
	$cursor = $autodb->find( -collection => 'TestAutoDB_1', -that => 'things' );
	ok( $cursor->get_next->this =~ /[4|5|6]/ );
	ok( $cursor->get_next->this =~ /[4|5|6]/ );
	ok( $cursor->get_next->this =~ /[4|5|6]/ );
	is( $cursor->get_next, undef );

	#test Cursor object creation (through autodb creation)
	my $cursor2 = Class::AutoDB->new(
			-dsn      =>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
			-find     => { -collection => 'TestAutoDB_1' }
	);
	is( ref($cursor2), "Class::AutoDB::Cursor",
			"calling find() in AutoDB constructor returns a Cursor object" );
	is( scalar $cursor2->get, 13, "one collection matches the query" );
}
