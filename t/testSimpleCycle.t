##
# Blackbox test the overall funtionality of AutoDB:
## Tests that simple cycles are mutally referencing, such that:
## $chris->friend($joe)
## $joe->friend($chris)
## both work.
##

use lib 't/';
use lib 'lib/';
use Data::Dumper;
use strict;
use Scalar::Util;
use Thing;
use Test::More qw/no_plan/;

require 'DBConnector.pm';
  Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          ); 
                          

{
my $joe = new Thing(-name=>'Joe',-sex=>'male');
my $bill = new Thing(-name=>'Bill',-sex=>'male');

## test cyclical refs
$joe->name('joey');
$bill->friends([$joe]);
$joe->friends([$bill, 'Mary Joe Bobby Sue Jeanne Twilleger']);

# killing off this instance will force a write of this object
&Class::AutoClass::DESTROY($joe);
&Class::AutoClass::DESTROY($bill);
}


{
require 'DBConnector.pm';
my $autodb =
  Class::AutoDB->new( 
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          );

			  
my $cursor = $autodb->find(-collection=>'Thing');
my @stuff = $cursor->get;
my $joe = $stuff[0];
my $bill = $stuff[1];


is($joe->name,"joey","first object exists in database");
is($bill->name,"Bill","second object exists in database");
is($joe->friends->[0]->name,'Bill',"refenced object is reachable from first object's list");
is($joe->friends->[1],'Mary Joe Bobby Sue Jeanne Twilleger',"scalar is reachable from first object's list");
is($bill->friends->[0]->name,'joey',"refenced object is reachable from second object's list");
}


# cleanup
&DBConnector::DESTROY;
