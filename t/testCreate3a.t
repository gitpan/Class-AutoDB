use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use Place;
my $DBC = new DBConnector(noclean=>1);
my $dbh = $DBC->getDBHandle;

# this test uses class Place, which specifies that it belongs to collections Place and Thing. Thing
# collecion will be created with Place's keys (since the system does not know about the Thing schema yet)
# but will be altered when the Thing schema is available (see testCreate3b.t)

SKIP: {
	skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
	
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
	);
	
	my $fortress = new Place(
														-name     => 'Fortress of Solitude',
														-location => 'not telling',
														-sites=> ['ice, lots of ice. Oh, and peguins'],
													);

	$fortress->store;

  # Place is in collections Place and Thing. Thing would have been created with Place's keys 
  my $T_rows = $dbh->selectrow_array('select count(oid) from Thing');
  is(scalar $T_rows, 1);
  my $T_F_rows = $dbh->selectrow_array('select count(oid) from Thing_sites');
  is(scalar $T_F_rows, 1); # not created, since Thing schema was unavailable at creation time
  my $P_rows = $dbh->selectrow_array('select count(oid) from Thing');
  is(scalar $P_rows, 1);
  my $P_F_rows = $dbh->selectrow_array('select count(oid) from Thing_friends');
  is(scalar $P_F_rows, undef); # not created, since Thing schema was unavailable at creation time

  # check the collections table
  my $collection = $dbh->selectall_hashref("select * from $Class::AutoDB::Registry::COLLECTION_TABLE", 3); # order by collection
  is($collection->{Place}->{class_name}, 'Place');
  is($collection->{Thing}->{class_name}, 'Place');
}
1;