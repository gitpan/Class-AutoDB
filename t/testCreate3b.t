use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use Thing;
use Person;
my $DBC = new DBConnector(noclean=>0);
my $dbh = $DBC->getDBHandle;

# this tests that the collection schema for collection Thing will alter the one set up in testCreate3a.t
# now that Thing is available (by virtue of the perl 'use Thing' statement).

SKIP: {
	skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
	
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
			-alter => 1
	);
	
		my $joe = new Person(
														-name    => 'Joe',
														-sex     => 'male',
													);
  for (1..3) {
    # Thing belongs to collection 'Thing'
    Thing->new(-name=>"thingy$_", -sex=>"you check!", -friends=>[$joe] )->store;
  }

  # Check that Thing schema has been appropriately altered
  my $T_rows = $dbh->selectrow_array('select count(oid) from Thing');
  is(scalar $T_rows, 4); # one from testCreate3a.t
  my $T_F_rows = $dbh->selectrow_array('select count(oid) from Thing_sites');
  is(scalar $T_F_rows, 1); # from Place schema, created in 
  my $P_F_rows = $dbh->selectrow_array('select count(oid) from Thing_friends');
  is(scalar $P_F_rows, 3);

  # check the collections table
  my $collection = $dbh->selectall_hashref("select * from $Class::AutoDB::Registry::COLLECTION_TABLE", 2); # order by class
  ok($collection->{Place}->{collection_name} =~ /['Thing'|'Place']/);
  is($collection->{Thing}->{collection_name}, 'Thing');
}
1;