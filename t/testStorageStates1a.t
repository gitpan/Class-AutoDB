use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Scalar::Util;
use DBConnector;
use Class::AutoDB;
use Person;
no warnings; ## suppress unititialized variable warnings

my $DBC = new DBConnector( noclean => 1 );
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates1a specifically sets up for testing implicit persistence of compound (having a list) objects

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
 my($bid,$jid,$mid);                       
                                         
  my $joe=new Person(-name=>'Joe',-sex=>'male');
  my $mary=new Person(-name=>'Mary',-sex=>'female');
  my $bill=new Person(-name=>'Bill',-sex=>'male');
  
  $jid = $joe->{__object_id};
  $mid = $mary->{__object_id};
  $bid = $bill->{__object_id};
  
  # Set up friends lists
  $joe->friends([$mary,$bill]);
  $mary->friends([$joe,$bill]);
  $bill->friends([$joe,$mary,'a doll named sue']);

  # only necessary for testing (we force implicit collection by --refcount to zero)
  Scalar::Util::weaken($joe);
  Scalar::Util::weaken($mary);
  Scalar::Util::weaken($bill);
  
  is(1,1); #just to quiet the test harness ;)
  sleep 1; # give I/O time to catch up before test harness pulls our handle
}