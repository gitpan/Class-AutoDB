##
# Blackbox test the overall funtionality of AutoDB:
## Test object creation, in-memory alteration, and DB storage. Ensure circular refs are eliminated.
##
use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Person;
use Class::AutoDB;
use strict;
use Scalar::Util ();

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
my($DBC, $DBH);

BEGIN {
 require 'DBConnector.pm';
 $DBC = new DBConnector;
 $DBH = $DBC->getDBHandle;
}

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;


my $autodb = Class::AutoDB->new(
		                  -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS,
                         );

{
my $joe = new Person(-name=>'Joe',-sex=>'male');
my $trudy = new Person(-name=>'Trudy',-sex=>'female');
my $mary = new Person(-name=>'Mary',-sex=>'female');
my $bill = new Person(-name=>'Bill',-sex=>'male');

is($joe->name, "Joe", "checking first object's data");
is($joe->sex, "male", "checking first object's data");
is($trudy->name, "Trudy", "checking second object's data");
is($trudy->sex, "female", "checking second object's data");
is($mary->name, "Mary", "checking third object's data");
is($mary->sex, "female", "checking third object's data");
is($bill->name, "Bill", "checking forth object's data");
is($bill->sex, "male", "checking forth object's data");

# make edits prior to going out of scope (object hasn't been written to DB yet)
$joe->name('Joey');
is($joe->name, "Joey", "checking first object's data altered data in memory");
#sleep(30);
my $result = $DBH->selectall_arrayref('select count(*) from Person where name="Joey"');
is($result->[0]->[0],0, "checking first object's data altered data not (yet) altered in database");
Scalar::Util::weaken($joe);
$result = $DBH->selectall_arrayref('select count(*) from Person where name="Joey"');
is($result->[0]->[0],1, "checking first object's data written to database after object out of scope");

# Set up friends lists
$bill->friends(['this','that']);
$trudy->friends([$mary,$bill,'this']);
# this sets up a race condition. If test fails, it might be due to DB reaction time (passes 100% for me)
Scalar::Util::weaken($trudy);
Scalar::Util::weaken($mary);
Scalar::Util::weaken($bill);
# sleep(1);
my $object_result = $DBH->selectall_arrayref('select * from Person where name="Trudy"');
my $list_result = $DBH->selectall_hashref("select * from Person_friends", 1);
my $id = $object_result->[0]->[0];
ok(exists $list_result->{$id},"object and list are written to database upon destruction");

# reconstitute Trudy
my $cursor = $autodb->find(-collection=>'Person', -name=>'Trudy');
#print Dumper $cursor;
my $trudy_lives_again = $cursor->{objects}->[0];

# test with joe obj (already in db)
my $bill_lives_again = $trudy_lives_again->friends([$bill]);
is($bill_lives_again->[0]->name, "Bill");
#TODO: test with outsider object
}
}
