use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::Registration;
use Class::AutoClass::Root;
use DBConnector;
use Person;
use Thing;
use DBI;
use strict;

use vars qw($REGISTRY $REGISTRY_OID $OBJECT_TABLE $OBJECT_COLUMNS);
$REGISTRY_OID=1;		# object id for registry
$OBJECT_TABLE='_AutoDB';	# default for Object table
$OBJECT_COLUMNS=qq(id int not null auto_increment, primary key (id), object longblob);
my $DBC = new DBConnector();
my $dbh = $DBC->getDBHandle;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

my $autodb = Class::AutoDB->new(
                                 -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                                 -user=>$DBConnector::DB_USER,
                                 -password=>$DBConnector::DB_PASS
                               );

my $transientRegistryTestObject1 = new Class::AutoDB::Registry;
my $transientRegistryTestObject2 = new Class::AutoDB::Registry;
my $savedRegistryTestObject1 = new Class::AutoDB::Registry(
                                                            -dbh=>$autodb->dbh,
                                                            -object_table=>'_AutoDB_Object1');                                                          
my $savedRegistryTestObject2 = new Class::AutoDB::Registry(
                                                            -dbh=>$autodb->dbh,
                                                            -object_table=>'_AutoDB_Object2');

# test objects
is(ref($transientRegistryTestObject1), "Class::AutoDB::Registry");
is(ref($transientRegistryTestObject2), "Class::AutoDB::Registry");
is(ref($savedRegistryTestObject1), "Class::AutoDB::Registry");
is(ref($savedRegistryTestObject2), "Class::AutoDB::Registry");

# test register
my $registry = $transientRegistryTestObject1->register( new Class::AutoClass::Args(
                                      -class=>'Class::Rodent',
                                      -collection=>'Disney',
                                      -keys=>qq(name string, sex string, friends list(string))));
                                                         
is(ref($registry),"Class::AutoDB::Registration","register returns a Class::AutoDB::Registration object");
$transientRegistryTestObject1->register
    (new Class::AutoClass::Args(-class=>'TestClass',-collection=>'Disney',
     -keys=>qq(string_key string,integer_key integer,float_key float,object_key object, list_key list(string))));
$transientRegistryTestObject1->register
    (new Class::AutoClass::Args(-class=>'TestClass',-collection=>'Disney',
     -keys=>qq(string_key string,another_key string)));

my $collection_keys = $transientRegistryTestObject1->collections->[0]->{_keys};
is($collection_keys->{another_key}, "string", "making sure new key added");
is($collection_keys->{string_key}, "string", "same key added twice");
is($collection_keys->{friends}, "list(string)", "making sure original keys remain");
eval{  
  $transientRegistryTestObject1->register(new Class::AutoClass::Args(
                                           -class=>'TestClass',-collection=>'Disney',
                                           -keys=>qq(string_key string,another_key integer,alter_key string)));
};
ok($@, "redefining a key should throw an exception");                                       

# test collections
$transientRegistryTestObject2->register(new Class::AutoClass::Args(
                                          -class=>'Class::Person',
                                          -collection=>'Person',
                                          -keys=>qq(name string, sex string, friends list(string))));
$transientRegistryTestObject2->register(new Class::AutoClass::Args(
                                          -class=>'Class::Duck',
                                          -collection=>'Duck',
                                          -keys=>qq(species string, gender string, prey list(string))));
                                          
my $known_collection = $transientRegistryTestObject2->collection("Person");
is(ref($known_collection), 'Class::AutoDB::Collection');
is($known_collection->{name}, "Person", "collection('known_collection_name') returns correct collection");
is($transientRegistryTestObject2->collection("foo"), undef, "collection('unknown_name') returns undef");
is($transientRegistryTestObject2->collections->[0]->{name}, "Person", "testing all registered collections are retrieved");
is($transientRegistryTestObject2->collections->[1]->{name}, "Duck", "testing all registered collections are retrieved");

my (%regs, $ary_ref);

# test exists
$savedRegistryTestObject1->register(new Class::AutoClass::Args(
                                      -class=>'Class::Person',
                                      -collection=>'Person',
                                      -keys=>qq(name string, sex string, enemy list(string))));
                                          
$savedRegistryTestObject2->register(new Class::AutoClass::Args(
                                      -class=>'Class::Duck',
                                      -collection=>'Duck',
                                      -keys=>qq(species string, gender string, prey list(string))));

is($savedRegistryTestObject2->exists,0,"exists flag false without create");
$savedRegistryTestObject2->create;
is($savedRegistryTestObject2->exists,1,"exists flag true after create");

is($savedRegistryTestObject1->object_table, "_AutoDB_Object1", "object_table name is correct (in registry object) for implicit writes");
is($savedRegistryTestObject2->object_table, "_AutoDB_Object2", "object_table name is correct (in registry object) for explicit writes");

$ary_ref = $dbh->selectall_arrayref("show tables");
foreach(@$ary_ref){
  $regs{lc("@$_")}++; # mysql decides to lc tables on some platforms, apparently
}
ok(exists $regs{("_autodb_object2")}, "object_table name preserved in registry written to database");
ok(exists $regs{("duck")}, "collection name written to database");
ok(exists $regs{("duck_prey")}, "collection name list written to database");

# test get
$savedRegistryTestObject1->register( new Class::AutoClass::Args(
                                      -class=>'Class::Person',
                                      -collection=>'Person',
                                      -keys=>qq(name string, sex string, enemy list(string))));
ok(! exists $regs{"_autodb_object1"}); # _AutoDB_Object1 still does not exist without explicit write              
$savedRegistryTestObject1->create;
$ary_ref = $dbh->selectall_arrayref("show tables");
foreach(@$ary_ref){
  $regs{lc("@$_")}++; # mysql decides to lc tables on some platforms, apparently
}
ok(exists $regs{("_autodb_object1")},"_AutoDB_Object1 written after create called");
my @got = $savedRegistryTestObject1->get;
is(ref($got[0]),"Class::AutoDB::Collection");
is( $got[0]->name,"Person", "get() got created collection");
# register another colection (prior to create). savedRegistryTestObject1 now has Person,Duck
$savedRegistryTestObject1->register(new Class::AutoClass::Args(
                                      -class=>'Class::Duck',
                                      -collection=>'Duck',
                                      -keys=>qq(species string, gender string, prey list(string))));                            
$savedRegistryTestObject1->create;
my $got = $savedRegistryTestObject1->get;
is( $got->[0]->name,"Person", "get() still holds original collection");
is( $got->[1]->name,"Duck", "get() holds new collection");

# make sure multiple collections can be maintained in registry
new Person(-name=>'Joe',-sex=>'male');
new Thing(-name=>'gloop',-sex=>'asexual');
my $fetched_reg = $dbh->selectall_arrayref("select * from _AutoDB_Object1 where id='Registry'")->[0]->[1];
my $thaw;
eval $fetched_reg; # sets thaw
my $name2coll = $thaw->{name2coll};
is(scalar keys %$name2coll, 2);

# test drop - Person collection is first
my @collections = $savedRegistryTestObject1->collections;
$savedRegistryTestObject1->drop($collections[0]);
# make sure tables are dropped for person keys (Person and Person_enemy)
my $tables = $dbh->selectall_hashref("show tables",1);
ok( ! exists $tables->{Person} );
ok( ! exists $tables->{Person_enemy} );
# AND from the registry
$fetched_reg = $dbh->selectall_arrayref("select * from _AutoDB_Object1 where id='Registry'")->[0]->[1];
$thaw = undef;
eval $fetched_reg; # sets thaw
$name2coll = $thaw->{name2coll};
is(scalar keys %$name2coll, 1);
$savedRegistryTestObject1->drop;
$tables = $dbh->selectall_hashref("show tables",1);
ok( ! exists $tables->{_AutoDB_Object1} );
}
1;