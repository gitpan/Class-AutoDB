use strict;
use lib qw(. t ../lib);
use Class::AutoDB;
use AnotherPerson;
use Test::More qw/no_plan/;
use DBConnector;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates7a sets up conditions to be tested in testStorageStates7b

my $DBC = new DBConnector(noclean=>1);
my $dbh = $DBC->getDBHandle;


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
	
	# Set up friends lists (not persisted, since they are AutoClass keys but not AutoDB keys)
	$joe->friends(  [ $mary, $bill ] );
	$mary->friends( [ $joe,  $bill ] );
	$bill->friends( [ $joe,  $mary ] );
	
	# these should be exposed randomly to test implicit and explicit storage conbinations
  $joe->store;
 $mary->store;
	$bill->store;
	
	 is(1,1); #just to quiet the test harness ;)
}
1;