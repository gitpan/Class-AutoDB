use lib qw(.. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use DBConnector;
use TestAutoDB_1;
use Error qw(:try);
use strict;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
my $DBC          = new DBConnector( noclean => 1 );
my $DBH          = $DBC->getDBHandle;
my $OBJECT_TABLE = '_AutoDB';                         # default for Object table
SKIP: {
	skip
"! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again",
		1
		unless $DBC->can_connect;
	my $exception;

	# passing create=0 flag should not add collection - throws error if collection doesn't exist
try {
	my $autodb3 = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
			-create   => 0
	);
  return;
}
catch Error with {
  $exception = shift;   # Get hold of the exception object
};
ok($exception =~ /EXCEPTION/,"collection doesn't exist and cannot be added while -create=>0 is set in AutoDB params");	

}
