use lib 't/';
use Data::Dumper; ## only for testing
use strict;
use DBI;
use TestAutoDB_3;
use DBConnector;
use Class::AutoDB;
use Class::AutoClass::Args;
use Class::AutoDB::Cursor;
use Test::More qw/no_plan/;

my($cursor, $autodb);
my $DBI = new DBConnector;
my $dbh = $DBI->getDBHandle;
### test object creation (overtly test with calling params)
my $data = {
                 'search' => {
                               'collection' => 'TestAutoDB_3'
                             },
                 'dbh' => $dbh,
                 'collection' => bless( {
                                          '_tables' => undef,
                                          'name' => 'TestAutoDB_3',
                                          '__persist' => 1,
                                          '_keys' => {
                                                       'other' => 'list(string)',
                                                       'that' => 'string',
                                                       'this' => 'int'
                                                     }
                                        }, 'Class::AutoDB::Collection' )
               };
               
$data = bless $data, "Class::AutoClass::Args";
my $cursor = Class::AutoDB::Cursor->new($data);
is(ref($cursor), "Class::AutoDB::Cursor", "calling cursor() with the expected params");

require 'DBConnector.pm';
### test Cursor object creation (through autodb creation)

$cursor = Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS,
                            -find=>{-collection=>'TestAutoDB_3'}
                          );

# skip for now, not sure if this is desired
#is(ref($cursor), "Class::AutoDB::Cursor", "calling find() in AutoDB constructor returns a Cursor object");


$autodb = Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          );


$cursor = $autodb->find(-collection=>'TestAutoDB_3');
is(ref($cursor), "Class::AutoDB::Cursor", "calling find() as a method on an AutoDB object returns a Cursor object");

### test Cursor functions/methods
# _fetch_statement
my $sql = Class::AutoDB::Cursor::_fetch_statement("CollectionName", "ID");
is($sql,'SELECT * FROM CollectionName WHERE object = ID',"_fetch_statement creates SQL without list");
my $sql = Class::AutoDB::Cursor::_fetch_statement("CollectionName", "ID", "ListName");
is($sql,'SELECT * FROM CollectionName_ListName WHERE object = ID', "_fetch_statement creates SQL with list");

# _rebless
is(ref(Class::AutoDB::Cursor::_rebless("saint")), 'saint');

# _slot
# most of _slot's functionality is tested through the high-level integration tests, since database
# connectitivty and collection writing and updating is necessary

# _get
is($cursor->get,0, "no collections are currently registered");


{
# populate the collection
my $thingy = TestAutoDB_3->new(-this=>1, -that=>'thingy1', -other=>["one","two"]);
&Class::AutoClass::DESTROY($thingy);
}
$cursor = $autodb->find(-collection=>'TestAutoDB_3');
is($cursor->get,1, "one collection is currently registered");


# _get_next
# not yet implemented


# cleanup
# &DBConnector::DESTROY;
