##
# Blackbox test the overall funtionality of AutoDB:
## Test that two objects that point to a third object will have same data when these objects are resurrected (even if that
## common object is altered and stored later). 

use lib qw(. t ../lib);
use strict;
use Person;
use DBConnector;
use Test::More qw/no_plan/;
use Class::AutoDB;

my $DBC = new DBConnector(noclean=>0);

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

  my $autodb = Class::AutoDB->new(
                              -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                              -user=>$DBConnector::DB_USER,
                              -password=>$DBConnector::DB_PASS
                            ); 
                            
  my $joe = Person->new(-name=>'Joe',-sex=>'male');
  my $bill = Person->new(-name=>'Bill',-sex=>'male');
  my $eddy = Person->new(-name=>'Eddy',-sex=>'male');
  
  $eddy->friends(["Glenda","Trixie",$joe]);
  $bill->friends([$eddy,$joe]);

  $bill->store;
  $eddy->store;
  $joe->name('Joey'); 
  $joe->store;
  
  my $cursor = $autodb->find(-collection=>'Person', -name=>'Joey');
  ($joe) = $cursor->get;
  $cursor = $autodb->find(-collection=>'Person', -name=>'Bill');
  ($bill) = $cursor->get;
  $cursor = $autodb->find(-collection=>'Person', -name=>'Eddy');
  ($eddy) = $cursor->get;
  
  is($bill->name,"Bill","Bill object exists in database");
  is($eddy->name,"Eddy","Eddy object exists in database");
  is($joe->name,"Joey","Joe's changed value was persisted");
  
  # test inter-relationships
  is($eddy->friends->[0],'Glenda');
  is($eddy->friends->[1],'Trixie');
  is($eddy->friends->[2]->name,'Joey',qq/Eddy's friends check out/);
  
  is($bill->friends->[0]->name,'Eddy');
  is($bill->friends->[1]->name,'Joey',qq/Bill's friends check out/);
  }