use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use AnotherPerson;
my $DBC = new DBConnector(noclean=>1); # don't clean up
my $dbh = $DBC->getDBHandle;

# regression test for defect:
# [ 1026161 ] classes named differently than package name are not stored
# see: www.sourceforge.net/projects/isbiology bug tracker

# this test uses class AnotherPerson, which specifies use of collection 'Person' (but does not 'use' or inherit from it);

SKIP: {
	skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
	
	my $autodb = Class::AutoDB->new(
			-dsn =>
				"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			-user     => $DBConnector::DB_USER,
			-password => $DBConnector::DB_PASS
	);
	my $joe = new AnotherPerson(
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
	my $bill = new AnotherPerson( -name => 'Bill', -sex => 'male' );

	# Set up friends lists
	$joe->friends(  [ $mary, $bill ] );
	$mary->friends( [ $joe,  $bill ] );
	$bill->friends( [ $joe,  $mary ] );
	
	$joe->store;
	$mary->store;
	$bill->store;

	# retrieve objects from DB
	my $cursor=$autodb->find(-collection=>'Person');
	is($cursor->count, 3);

	for my $obj ($cursor->get_next) {
	  is($obj->_CLASS,'AnotherPerson');
	}
  
  # obj is class AnotherPerson but in the Person collection, so AnotherPerson collection should not exist
  my $AP_rows = $dbh->selectrow_array('select count(*) from AnotherPerson');
  is(scalar $AP_rows, undef);
  my $AP_H_rows = $dbh->selectrow_array('select count(*) from AnotherPerson_hobbies');
  is(scalar $AP_H_rows, undef);
  # Person collection should  have been created using AnotherPerson's schema (since Person did not exist already)
  my $P_rows = $dbh->selectrow_array('select count(*) from Person');
  is(scalar $P_rows, 3);
  my $P_F_rows = $dbh->selectrow_array('select count(*) from Person_friends');
  is(scalar $P_F_rows, undef);
  my $P_H_rows = $dbh->selectrow_array('select count(*) from Person_hobbies');
  is(scalar $P_H_rows, 3);
  # check the collections table
  my $collection = $dbh->selectall_hashref("select * from $Class::AutoDB::Registry::COLLECTION_TABLE", 2);
  is($collection->{AnotherPerson}->{class_name}, 'AnotherPerson');
  is($collection->{AnotherPerson}->{collection_name}, 'Person');
}
1;
