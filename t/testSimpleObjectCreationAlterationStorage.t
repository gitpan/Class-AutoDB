##
# Blackbox test the overall funtionality of AutoDB
## Test object creation, in-memory manipulation and storage.
##
use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use TestAutoDB_3;
use Class::AutoDB;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
my($DBC, $DBH);

BEGIN {
 require 'DBConnector.pm';
 $DBC = new DBConnector;
 $DBH = $DBC->getDBHandle;
}

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;


# connect through new AutoDB object:
# - check above is written to database
# - fetch collection written above, and alter  
my $autodb =
  Class::AutoDB->new(
		          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                  -user=>$DBConnector::DB_USER,
                  -password=>$DBConnector::DB_PASS
                 );


# create objects in memory
{
# populate the collection
my $thingy1=TestAutoDB_3->new(-this=>1, -that=>'thingy1', -other=>["one","two"]);
is($thingy1->this,1,"collection ok in memory");
$thingy1->this(2);
is($thingy1->this,2,"collection altered in memory");
} #ref to thingy1 has now gone out of scope, so thingy1 is written to DB

{
my $cursor = $autodb->find(-collection=>'TestAutoDB_3');
my @stuff = $cursor->get;
my $obj_to_update = $stuff[0];
is($obj_to_update->this,2,"scalar written to database");
$obj_to_update->this(4); #alter in memory
is($obj_to_update->this,4,"scalar element correctly altered in memory");
is(ref($obj_to_update->other),'ARRAY',"list written to database");
$obj_to_update->other(['five','six']);
is($obj_to_update->other->[0],'five',"list element correctly altered in memory");                                                                    
is($obj_to_update->other->[1],'six',"list element correctly altered in memory");  
&Class::AutoClass::DESTROY($obj_to_update);
} #object goes out of scope and changes are committed to database


# now test that above changes were committed
{         
my $cursor = $autodb->find(-collection=>'TestAutoDB_3');
my @stuff = $cursor->get;
my $obj_to_scan = $stuff[0];
is($obj_to_scan->this,4,"retrieved and altered scalar written correctly");
is($obj_to_scan->other->[0],'five',"retrieved and altered list element written correctly");
is($obj_to_scan->other->[1],'six',"retrieved and altered list element written correctly");
}
}