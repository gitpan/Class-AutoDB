use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::Registration;
use DBConnector;
use Error qw(:try);
use strict;

use vars qw($REGISTRY $REGISTRY_OID $OBJECT_TABLE $OBJECT_COLUMNS);
$REGISTRY_OID = 'Registry';    # object id for registry
$OBJECT_TABLE = '_AutoDB';     # default for Object table
my $DBC = new DBConnector( noclean => 0 );
my $dbh = $DBC->getDBHandle;

SKIP: {
 skip
"! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again",
   1
   unless $DBC->can_connect;

my($saved,$thaw);
 # test in-memory register
 my $registry = new Class::AutoDB::Registry;
 is( ref($registry), "Class::AutoDB::Registry" );
 $saved = $dbh->selectrow_array("select count(*) from $OBJECT_TABLE");
 is( $saved, undef, 'in-memory registry not written to database' );
 is( scalar @{ $registry->collections },
  0, 'unregistered registry has no collections' );
 $registry->register(
  -class      => 'Class::Person',
  -collection => 'Person',
  -keys       => qq(name string, sex string, friends list(string))
 );
 is( ref($registry), "Class::AutoDB::Registry",
  "register returns a Class::AutoDB::Registry object" );
 is( scalar @{ $registry->collections },
  1, 'correct number of collections were registered' );
 my $ot = $dbh->selectrow_array("select count(*) from $OBJECT_TABLE");
 is( $ot, undef, 'register exist only in memory' );

 ($saved,$thaw)=undef;
 # register a collection, put it and check again
 my $saved_registry =
   new Class::AutoDB::Registry    # retrieve an existing collection
   (
   -autodb => Class::AutoDB->new(
    -dsn =>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
    -user     => $DBConnector::DB_USER,
    -password => $DBConnector::DB_PASS,
   ),
   -object_table => $OBJECT_TABLE
   );                             
 # get saved registry from database
 $saved =
   $dbh->selectall_hashref(
   qq/select * from $OBJECT_TABLE where oid="$REGISTRY_OID"/, 1 );
 eval $saved->{$REGISTRY_OID}->{object};    # sets the 'thaw' handle
 is( $thaw->{object_table}, $OBJECT_TABLE );
 is( keys %{ $thaw->{name2coll} },0, 'registry  created without collections (expected)' );
 $saved_registry->register(
  -class      => 'Class::Person',
  -collection => 'Person',
  -keys       => qq(name string, sex string, friends list(string))
 );
 $saved_registry->put;
 # this method:
 is( scalar keys %{ $saved_registry->_retrieve->{name2coll} },1);
 # and this one are equivalent, but done here to double-check the _retrieve method
 $saved =
   $dbh->selectall_hashref(
  qq/select * from $OBJECT_TABLE where oid="$REGISTRY_OID"/, 1 );
 eval $saved->{$REGISTRY_OID}->{object};    # sets the 'thaw' handle
 is( $thaw->{object_table}, $OBJECT_TABLE );
 is( keys %{ $thaw->{name2coll} },1, 'collection persisted one collection (expected)' );

($saved,$thaw)=undef;
 # test drop and create
 $saved_registry->create('Thing');          # create one collection
 is( scalar keys %{ $saved_registry->_retrieve->{name2coll} }, 1 );
 $saved_registry->put;
 is( scalar keys %{ $saved_registry->_retrieve->{name2coll} }, 2 );
 ( $saved, $thaw ) = undef;
 $saved =
   $dbh->selectall_hashref(
  qq/select * from $OBJECT_TABLE where oid="$REGISTRY_OID"/, 1 );
 eval $saved->{$REGISTRY_OID}->{object};    # sets the 'thaw' handle
 is( $thaw->{object_table}, $OBJECT_TABLE );
 is( keys %{ $thaw->{name2coll} },2, 'collection persisted one collection (expected)' );
 $saved_registry->drop('Person');           # drop one collection
 is( scalar keys %{ $saved_registry->_retrieve->{name2coll} }, 1 );
 is( ref $saved_registry->_retrieve->{name2coll}->{Thing},'Class::AutoDB::Collection' );
 is( keys %{$saved_registry->_retrieve->{name2coll}},1, 'one collection remains after other was dropped (expected)' );
 $saved_registry->drop;                     # drop entire database
 is( $saved_registry->{name2coll},undef, 'in-memory registry was dropped' );
 is( $saved_registry->_retrieve->{name2coll}, undef, 'no collections persisted after registry was dropped (expected)' );
 my $empty_registry = new Class::AutoDB::Registry(-dbh=>$dbh);
 is($dbh->selectrow_array("select count(*) from $OBJECT_TABLE"),undef,'object table not written until create called');
 my $exception;
 try {
   $empty_registry->create;  # create entire database - illegal
  return;
}
catch Error with {
  $exception = shift;   # Get hold of the exception object
};
ok($exception =~ /EXCEPTION/,'creating an empty Registry is illegal - requires named collections');
 is(scalar keys %{$saved_registry->{name2coll}},0,'create unnamed collection does not exists in memory (expected)');
 is($dbh->selectrow_array("select count(*) from $OBJECT_TABLE"),0,'object table exists (empty) after create');
 isnt(ref $empty_registry->_retrieve, 'Class::AutoDB::Registry'); # nothing written yet
 $empty_registry->put;
 # registry will be put into place sans collections
 is(ref $empty_registry->_retrieve, 'Class::AutoDB::Registry'); # nothing written yet
 is( scalar keys %{ $empty_registry->_retrieve->{name2coll} },0,'unnamed collections not persisted');
 $saved_registry->create('Person');  # create one collection
 is(scalar keys %{$saved_registry->{name2coll}},1,'create named collection exists in memory');
 is( scalar keys %{ $empty_registry->_retrieve->{name2coll} },0,'registry not persisted until put');
 $saved_registry->put;
 is( scalar keys %{ $empty_registry->_retrieve->{name2coll} },1);
}
1;
