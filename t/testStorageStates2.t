use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use Person;
no warnings; ## suppress unititialized variable warnings

my $DBC = new DBConnector;
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates2 specifically tests explicit persistence of simple (no list) objects

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
                        
  my $joe=new Person(-name=>'Joe',-sex=>'male');
  my $mary=new Person(-name=>'Mary',-sex=>'female');
  my $bill=new Person(-name=>'Bill',-sex=>'male');
  
  my $jid = $joe->{__object_id};
  my $mid = $mary->{__object_id};
  my $bid = $bill->{__object_id};

  # explicitly store objects
  $joe->store;
  $bill->store;
  $mary->store;

# compare inserts with expected results

  # test person search keys
  my $peeps = $dbh->selectall_arrayref('select * from Person');
  for ( 0..@$peeps-1 ) {
    ok($peeps->[$_]->[0] =~ qq[$jid|$bid|$mid], "test oject id");
    ok($peeps->[$_]->[1] =~ qq[Joe|Bill|Mary], "test oject names");
    ok($peeps->[$_]->[2] =~ qq[male|female], "test oject genders");
  }
}
