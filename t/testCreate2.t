use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use ExtendedPerson;
my $DBC = new DBConnector(noclean=>0);
my $dbh = $DBC->getDBHandle;

# this test uses ExtendedPerson, which inherits from Person and adds the key 'weakness' (string). We expect to see 
# Person's base keys and ExtendedPerson's 'weakness' key in the collection and lookup tables. ExtenededPerson
# is in the Person collection

SKIP: {
	skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
	
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
	);
	
	my $superhuman = new ExtendedPerson(
														-name    => 'Super Man',
														-sex     => 'male',
														-alias   => 'Man of Steel',
														-hobbies => [ 'leaping tall buildings', 'outrunning bullets' ],
														-friends=> ['lois lane'],
														-weakness=>'kryptonite'
													);

	$superhuman->store;

  # Person adds 'alias' key to top-level search keys and the friend list
  my $P_rows = $dbh->selectrow_array('select count(oid) from Person');
  is(scalar $P_rows, 1);
  my $P_F_rows = $dbh->selectrow_array('select count(oid) from Person_friends');
  is(scalar $P_F_rows, 1);
  my $P_H_rows = $dbh->selectrow_array('select count(oid) from Person_hobbies');
  is(scalar $P_H_rows, 2);
  my $P_alias_rows = $dbh->selectrow_array('select count(weakness) from Person');
  is(scalar $P_alias_rows, 1); 
  # check the collections table
  my $collection = $dbh->selectall_hashref("select * from $Class::AutoDB::Registry::COLLECTION_TABLE", 2);
  is($collection->{ExtendedPerson}->{class_name}, 'ExtendedPerson');
  is($collection->{ExtendedPerson}->{collection_name}, 'Person');
}
1;