use lib qw(. t ../lib);
use strict;
use DBConnector;
use Class::AutoDB;
use Thing;
use Test::More qw/no_plan/;
use Scalar::Util;

my $DBC = new DBConnector;
my $dbh = $DBC->getDBHandle;


SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

  my $autodb = Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          ); 
                          
  
  # create and immediately destroy (so that objects are persisted)
  for (1..3) {
    Scalar::Util::weaken( Thing->new(-name=>"friend$_", -sex=>'female' ) );
  }
     
  # verify the collections
  my $Tcursor = $autodb->find(-collection=>'Thing');
  is($Tcursor->count,3);
  while (my $thing = $Tcursor->get_next) {
    # do nothing - just moving the pointer over the collection
  }
  
  # try iterating grabbing next object from spent $cursor
  is($Tcursor->get_next,undef);
  is($Tcursor->count,3);
  isnt($Tcursor->get_next,undef,'count() resets iterator');
  
  # rinse, wash, repeat...
  while (my $thing = $Tcursor->get_next) {
    # do nothing - just moving the pointer over the collection
  }
  
  # try it again, after reset
  is($Tcursor->get_next,undef);
  $Tcursor->reset;
  isnt($Tcursor->get_next,undef);
  is($Tcursor->count,3);
  
}