use lib qw(.. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use DBConnector;
use TestAutoDB_2;
use strict;
use Class::AutoDB::Registry;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
my $DBC          = new DBConnector( noclean => 1 );
my $DBH          = $DBC->getDBHandle;
my $OBJECT_TABLE = '_AutoDB';                         # default for Object table
SKIP: {
	skip
"! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again",
		1
		unless $DBC->can_connect;

	my $thaw;
	# passing create=1 flag should drop existing registry and collections and create new
	my $autodb2 = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
			-create   => 1
	);
	my $result2 = $DBH->selectall_hashref( "select * from $OBJECT_TABLE", 1 );
	undef $thaw;
	eval $result2->{Registry}->{object};    #sets thaw
	is( scalar keys %{ $thaw->{name2coll} }, 1 );
	ok( not defined $thaw->{name2coll}->{TestAutoDB_1} );
	ok( defined $thaw->{name2coll}->{TestAutoDB_2} );
}
