use lib 't/';
use Test::More qw/no_plan/;
use Data::Dumper;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::Registration;
use DBConnector;
use DBI;
use strict;

use vars qw($REGISTRY $REGISTRY_OID $OBJECT_TABLE $OBJECT_COLUMNS);
$REGISTRY_OID=1;		# object id for registry
$OBJECT_TABLE='_AutoDB';	# default for Object table
$OBJECT_COLUMNS=qq(id int not null auto_increment, primary key (id), object longblob);
my $DBI = new DBConnector;
my $dbh = $DBI->getDBHandle;

my $autodb = Class::AutoDB->new(
                                 -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                                 -user=>$DBConnector::DB_USER,
                                 -password=>$DBConnector::DB_PASS
                               );
                               
my $transientRegistryTestObject1 = new Class::AutoDB::Registry;
my $transientRegistryTestObject2 = new Class::AutoDB::Registry;
my $savedRegistryTestObject1 = new Class::AutoDB::Registry(
                                                            -autodb=>$autodb,
                                                            -object_table=>'_AutoDB_Object1');                                                          
my $savedRegistryTestObject2 = new Class::AutoDB::Registry(
                                                            -autodb=>$autodb,
                                                            -object_table=>'_AutoDB_Object2');

# test objects
is(ref($transientRegistryTestObject1), "Class::AutoDB::Registry");
is(ref($transientRegistryTestObject2), "Class::AutoDB::Registry");
is(ref($savedRegistryTestObject1), "Class::AutoDB::Registry");
is(ref($savedRegistryTestObject2), "Class::AutoDB::Registry");

# test register
my $registry = $transientRegistryTestObject1->register(
                                                         -class=>'Class::Rodent',
                                                         -collection=>'Disney',
                                                         -keys=>qq(name string, sex string, friends list(string)));
                                                         
is(ref($registry),"Class::AutoDB::Registration","register returns a Class::AutoDB::Registration object");
$transientRegistryTestObject1->register
    (-class=>'TestClass',-collection=>'Disney',
     -keys=>qq(string_key string,integer_key integer,float_key float,object_key object, list_key list(string)));
$transientRegistryTestObject1->register
    (-class=>'TestClass',-collection=>'Disney',
     -keys=>qq(string_key string,another_key string));

my %collection_keys = %{%{$transientRegistryTestObject1->collections->[0]}->{_keys}}; # it just works, ok?
is($collection_keys{another_key}, "string", "making sure new key added");
is($collection_keys{string_key}, "string", "same key added twice");
is($collection_keys{friends}, "list(string)", "making sure original keys remain");
eval{  
  $transientRegistryTestObject1->register(
                                           -class=>'TestClass',-collection=>'Disney',
                                           -keys=>qq(string_key string,another_key integer,alter_key string));
};
ok($@ =~ /EXCEPTION/, "redefining a key should throw an exception");                                       

# test collections
$transientRegistryTestObject2->register(
                                          -class=>'Class::Person',
                                          -collection=>'Person',
                                          -keys=>qq(name string, sex string, friends list(string)));
$transientRegistryTestObject2->register(
                                          -class=>'Class::Duck',
                                          -collection=>'Duck',
                                          -keys=>qq(species string, gender string, prey list(string)));
                                          
my $known_collection = $transientRegistryTestObject2->collection("Person");
is(ref($known_collection), 'Class::AutoDB::Collection');
is($known_collection->{name}, "Person", "collection('known_collection_name') returns correct collection");
is($transientRegistryTestObject2->collection("foo"), undef, "collection('unknown_name') returns undef");
is($transientRegistryTestObject2->collections->[0]->{name}, "Person", "testing all registered collections are retrieved");
is($transientRegistryTestObject2->collections->[1]->{name}, "Duck", "testing all registered collections are retrieved");

my (%regs, $ary_ref);
{
  # this sets up an autoloaded registry
  require 'TestAutoDB_1.pm';
  $ary_ref = $dbh->selectall_arrayref("show tables");
  foreach(@$ary_ref){
   $regs{"@$_"}++;
  }
  ok(!(exists$regs{lc("_AutoDB_Object1")}), "auto registry not written until exit");
} #end of scope, _AutoDB_Object1 will be written


# test exists
$savedRegistryTestObject1->register(
                                      -class=>'Class::Person',
                                      -collection=>'Person',
                                      -keys=>qq(name string, sex string, enemy list(string)));
                                          
$savedRegistryTestObject2->register(
                                      -class=>'Class::Duck',
                                      -collection=>'Duck',
                                      -keys=>qq(species string, gender string, prey list(string)));
  
eval{ $transientRegistryTestObject1->exists };
ok($@ =~ /EXCEPTION/, "exists throws exception unless connected to the database");
is($savedRegistryTestObject1->exists,0,"registry does not exist in database without create");
$savedRegistryTestObject2->create;
is($savedRegistryTestObject2->exists,1,"created registry written to database");
is($savedRegistryTestObject1->object_table, "_AutoDB_Object1", "object_table name is correct (in registry object) for implicit writes");
is($savedRegistryTestObject2->object_table, "_AutoDB_Object2", "object_table name is correct (in registry object) for explicit writes");

$ary_ref = $dbh->selectall_arrayref("show tables");
foreach(@$ary_ref){
  $regs{"@$_"}++;
}

# _test_exists requires (in the perl sense) a file which autoloads testautodb_1
ok(exists $regs{lc("_AutoDB_Object2")}, "object_table name preserved in registry written to database");
ok(exists $regs{lc("duck")}, "collection name written to database");
ok(exists $regs{lc("duck_prey")}, "collection name list written to database");

# test get
$savedRegistryTestObject1->register(
                                      -class=>'Class::Person',
                                      -collection=>'Person',
                                      -keys=>qq(name string, sex string, enemy list(string)));

                      
ok(! exists $regs{lc("_AutoDB_Object1")}); # _AutoDB_Object1 still does not exist without explicit write              
$savedRegistryTestObject1->create;
$ary_ref = $dbh->selectall_arrayref("show tables");
foreach(@$ary_ref){
  $regs{"@$_"}++;
}
ok(exists $regs{lc("_AutoDB_Object1")},"_AutoDB_Object1 written after create called");
my @got = $savedRegistryTestObject1->get;
is(ref($got[0]),"Class::AutoDB::Collection");
is( $got[0]->name,"Person", "get() got created collection");
$savedRegistryTestObject1->register(
                                      -class=>'Class::Duck',
                                      -collection=>'Duck',
                                      -keys=>qq(species string, gender string, prey list(string)));
$savedRegistryTestObject1->create;
my $got = $savedRegistryTestObject1->get; 
is( $got->[0]->name,"Person", "get() still holds original collection");
is( $got->[1]->name,"Duck", "get() holds new collection");