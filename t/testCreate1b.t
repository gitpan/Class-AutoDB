use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use Person;
my $DBC = new DBConnector(noclean=>0);
my $dbh = $DBC->getDBHandle;

# this test uses collection Person, which was created using AnotherPerson's schema (see test testcreate1a.t)
# and needs to be altered (AnotherPerson's schema is not a complete subset of Person's). Therefore, this
# test examines the alteration

SKIP: {
	skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
	
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS,
			-alter => 1 # allow for schema alteration
	);
	my $joe = new Person(
														-name    => 'Joe',
														-sex     => 'male',
														-alias   => 'Joe Alias',
														-hobbies => [ 'mountain climbing', 'sailing' ],
														-friends=> ['dog is my co-pilot']
													);
	my $mary = new Person(
														 -name    => 'Mary',
														 -sex     => 'female',
														 -alias   => 'Mary Alias',
														 -hobbies => ['hang gliding'],
														 -friends=> [$joe]
													 );
	$joe->store;
	$mary->store;


  # Person adds 'alias' key to top-level search keys and the friend list
  my $P_rows = $dbh->selectrow_array('select count(distinct oid) from Person');
  is(scalar $P_rows, 5);
  my $P_F_rows = $dbh->selectrow_array('select count(distinct oid) from Person_friends');
  is(scalar $P_F_rows, 2);
  my $P_H_rows = $dbh->selectrow_array('select count(distinct oid) from Person_hobbies');
  is(scalar $P_H_rows, 4);
  my $P_alias_rows = $dbh->selectrow_array('select count(distinct alias) from Person');
  is(scalar $P_alias_rows, 2); 
  # check the collections table
  my $collection = $dbh->selectall_hashref("select * from $Class::AutoDB::Registry::COLLECTION_TABLE", 2);
  is($collection->{AnotherPerson}->{class_name}, 'AnotherPerson');
  is($collection->{Person}->{class_name}, 'Person');
  is($collection->{AnotherPerson}->{collection_name}, 'Person');
}
1;
