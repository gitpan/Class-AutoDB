##
# Blackbox test the overall funtionality of AutoDB:
## Test that objects will take a snapshot of a shared resource when that object is destroyed (and therefore written to the database).
## This means that two objects that point to a third object will have different data when these objects are resurrected. However, they
## _will_ have the same UID, which is embedded in the object
##

use lib qw(. t ../lib);
use strict;
use Thing;
use DBConnector;
use Test::More qw/no_plan/;
use Class::AutoDB;

my $DBC = new DBConnector;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

my $autodb = Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          ); 
                          
my $joe = Thing->new(-name=>'Joe',-sex=>'male');
my $bill = Thing->new(-name=>'Bill',-sex=>'male');
my $eddy = Thing->new(-name=>'Eddy',-sex=>'male');

$eddy->friends(["Glenda","Trixie"]);
$bill->friends([$eddy]);
$joe->name('Joey');

my $cursor = $autodb->find(-collection=>'Thing');
my @stuff = $cursor->get;

my $joe = $stuff[0];
my $bill = $stuff[1];
my $eddy = $stuff[2];

is($bill->name,"Bill","Bill object exists in database");
is($eddy->name,"Eddy","Eddy object exists in database");
is($joe->name,"Joey","Joe's changed value was persisted");

# test inter-relationships
is($eddy->friends->[0],'Glenda');
is($eddy->friends->[1],'Trixie',qq/Eddy's friends check out/);
is(ref($bill->friends->[0]),'Thing',qq/Bill's friend is a Thing instance/);
is($bill->friends->[0]->name,'Eddy',qq/retrieved Eddy through Bill's friend list/);
}