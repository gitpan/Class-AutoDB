use lib qw(. t ../lib);
use strict;
use DBConnector;
use Class::AutoDB;
use Person;
use Place;
use Thing;
use Test::More qw/no_plan/;

my $DBC = new DBConnector(noclean=>0);
my $dbh = $DBC->getDBHandle;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

  my $autodb = Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          ); 
                          
  
#   create and immediately destroy (so that objects are persisted)
  for (1..5) {
    # Person belongs to collection 'Person'
    Person->new(-name=>"person$_", -sex=>'female' )->store;
  }
  for (1..3) {
    # Thing belongs to collection 'Thing'
    Thing->new(-name=>"thingy$_", -sex=>'really not sure' )->store;
  }
  for (1..7) {
    # Place belongs to collections 'Place' and 'Thing'
    Place->new(-name=>"place$_", -location=>"somewhere$_", -sites=>["here$_","there$_"] )->store;
  }
  my($cursor);
  # retrieve by collection(s)
  $cursor = $autodb->find(-collection=>'Person');
  is($cursor->count,5);
  $cursor = $autodb->find(-collection=>'Place');
  is($cursor->count,7);
  $cursor = $autodb->find(-collection=>'Thing');
  is($cursor->count,10);
  $cursor = $autodb->find(-collection=>['Thing','Person']);
  is($cursor->count,15);
  $cursor = $autodb->find(-collection=>['foo']);
  is($cursor->count,0, "doesn't choke on invalid collection");
  $cursor = $autodb->find(-collection=>['Thing','Person','foo']);
  is($cursor->count,15, "doesn't choke on invalid collection with valid ones");
  # retrieve by class
  $cursor = $autodb->find(-class=>'Person');
  is($cursor->count,5);
  $cursor = $autodb->find(-class=>'Place');
  is($cursor->count,7);
  $cursor = $autodb->find(-class=>'Thing');
  is($cursor->count,3);
  $cursor = $autodb->find(-class=>['Thing','Place']);
  is($cursor->count,10);
  $cursor = $autodb->find(-class=>'foo');
  is($cursor->count,0,'invalid classes return count of 0');
  # retrieve by collection and class
  $cursor = $autodb->find(-collection=>'Person', -class=>'Person');
  is($cursor->count,5);
  $cursor = $autodb->find(-collection=>'Place', -class=>'Place');
  is($cursor->count,7);
  $cursor = $autodb->find(-collection=>'Thing', -class=>'Place');
  is($cursor->count,7);  
  $cursor = $autodb->find(-collection=>'Thing', -class=>'Thing');
  is($cursor->count,3);
  $cursor = $autodb->find(-collection=>'Thing', -class=>['Thing','Place']);
  is($cursor->count,10);
  $cursor = $autodb->find(-collection=>'Thing', -class=>['Thing','Place','foo']);
  is($cursor->count,10,"doesn't choke on invalid class");
  $cursor = $autodb->find(-collection=>'Thing', -class=>['Thing','Place','Person']);
  is($cursor->count,10,'ignores classes not associated with specified collection');
  # retrieve by attribute
  $cursor = $autodb->find(-class=>'Person', -name=>'person1');
  is($cursor->count,1);
  $cursor = $autodb->find(-collection=>'Thing', -class=>'Place', -location=>'somewhere4');
  is($cursor->count,1);
  $cursor = $autodb->find(-collection=>'Thing', -class=>'Thing', -name=>'thingy2');
  is($cursor->count,1);
  $cursor = $autodb->find(-collection=>'Place', -sites=>'here3'); # test find within list (Place_sites is a list)
  is($cursor->count,1);
}
