use lib qw(.. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use DBConnector;
use strict;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);

my  $DBC = new DBConnector();
my  $DBH = $DBC->getDBHandle;
my $OBJECT_TABLE='_AutoDB';        # default for Object table

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

	require 'TestAutoDB_1.pm';
	my $autodb = Class::AutoDB->new(
		                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
		                          -user=>$DBConnector::DB_USER,
		                          -password=>$DBConnector::DB_PASS,
		                          -drop=>0
		                        );
	my $result = $DBH->selectall_hashref("select * from $OBJECT_TABLE",1);
	my $thaw;
	eval $result->{Registry}->{object}; #sets thaw
	is(scalar keys %{$thaw->{name2coll}}, 1);
	ok(defined $thaw->{name2coll}->{TestAutoDB_1});

	require 'TestAutoDB_2.pm';
	my $autodb2 = Class::AutoDB->new(
		                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
		                          -user=>$DBConnector::DB_USER,
		                          -password=>$DBConnector::DB_PASS,
		                          -drop=>1
		                        );
	$result = $DBH->selectall_hashref("select * from $OBJECT_TABLE",1);
  is($result, undef);
}


