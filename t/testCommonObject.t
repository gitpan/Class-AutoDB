##
# Blackbox test the overall funtionality of AutoDB:
## Test that objects will take a snapshot of a shared resource when that object is destroyed (and therefore written to the database).
## This means that two objects that point to a third object will have different data when these objects are resurrected. However, they
## _will_ have the same UID, which is embedded in the object
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
                          

my $joe = new Thing(-name=>'Joe',-sex=>'male');
my $bill = new Thing(-name=>'Bill',-sex=>'male');
my $eddy = new Thing(-name=>'Eddy',-sex=>'male');

{
$eddy->friends(["James"]);
$joe->friends([$eddy]);

# killing off this instance will force a write of this object
&Class::AutoClass::DESTROY($joe);
}


# eddy and bill still live
{
$eddy->friends(["Glenda","Trixie"]);
$bill->friends($eddy);
}
# killing off this instance will force a write of this object
&Class::AutoClass::DESTROY($bill);
&Class::AutoClass::DESTROY($eddy);


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
#print Dumper @stuff;
my $joe = $stuff[0];
my $bill = $stuff[1];
my $eddy = $stuff[2];

is($joe->name,"Joe","first object exists in database");
is($bill->name,"Bill","second object exists in database");
is($eddy->name,"Eddy","third object exists in database");
my $joe_friend_list = $joe->friends->[0]->{friends};
is(scalar @{$joe_friend_list}, 1, "first object's friends list is incomplete (expected)");
my $bill_friend_list = $bill->friends->[0]->{friends};
is(scalar @{$bill_friend_list}, 2, "second object's friends list is complete");
my $joe_list_uid = $joe->friends->[0]->{UID};
my $bill_list_uid = $bill->friends->[0]->{UID};
ok($joe_list_uid eq $bill_list_uid, "UID is the same for both snapshots of the same object");
}

# cleanup
&DBConnector::DESTROY;
