use lib qw(. t ../lib);
use strict;
use DBConnector;
use Class::AutoDB;
use Person;
use Thing;
use Test::More qw/no_plan/;
use Data::Dumper; ##only for testing

my $DBC = new DBConnector;
my $dbh = $DBC->getDBHandle;


SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
                        
# populate the collections
my ($lucy,$ethel,$Pcursor,$Tcursor);
 $ethel = Person->new(-name=>'Ethel', -sex=>'female',-friends=>[$lucy] );
 $lucy = Person->new(-name=>'Lucy', -sex=>'female',-friends=>[$ethel] );

for (1..3) {
  Thing->new(-name=>"friend$_", -sex=>'female', -friends=>[$lucy,$ethel] );
}
   
# verify the collections
$Tcursor = $autodb->find(-collection=>'Thing');
is($Tcursor->count,3);
while (my $thing = $Tcursor->get_next) {
  is($thing->friends->[0]->name,'Lucy');
  is($thing->friends->[1]->name,'Ethel');
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

$Pcursor = $autodb->find(-collection=>'Person');
is($Pcursor->count,2);
# delete the Person entries (Things refer to them)
while (my $person = $Pcursor->get_next) {
  $autodb->del($person);
}

# verify Person deletions
is($Pcursor->count,0);

$Tcursor->reset;
# iterate over Tcursor collection
while (my $thing = $Tcursor->get_next) {
  is($thing->friends->[0]->name,undef,'deleted object cannot be accessed through its search keys');
  is($thing->friends->[1]->name,undef,'deleted object cannot be accessed through its search keys');
  isnt($thing->friends, undef, 'but be careful! you can still access them from their serialized referants');
}





}
