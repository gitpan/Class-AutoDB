use lib qw(. t ../lib);
use strict;
use DBConnector;
use Class::AutoDB;
use Person;
use Thing;
use Test::More qw/no_plan/;
use Scalar::Util;
use Data::Dumper; ##only for testing

my $DBC = new DBConnector();
my $dbh = $DBC->getDBHandle;

## note: 'del' and 'delete' are synonymous methods

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

  my $autodb = Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                            -user=>$DBConnector::DB_USER,
                            -password=>$DBConnector::DB_PASS
                          ); 
                          
  # populate the collections
  my ($lucy,$ethel,$Pcursor,$Tcursor);
  $ethel = Person->new(-name=>'Ethel', -sex=>'female',-friends=>[$lucy] ); # will be undef since lucy doesn't exist yet
  $ethel->store; # this will be committed to data store immediately
  $lucy = Person->new(-name=>'Lucy', -sex=>'female',-friends=>[$ethel] );
  $lucy->store; # ditto
  
  # create and immediately destroy (so that objects are persisted)
  for (1..3) {
    Scalar::Util::weaken( Thing->new(-name=>"friend$_", -sex=>'female', -friends=>[$lucy,$ethel] ) );
  }
     
  # verify the collections
  $Tcursor = $autodb->find(-collection=>'Thing');
  is($Tcursor->count,3);
  while (my $thing = $Tcursor->get_next) {
    is($thing->friends->[0]->name,'Lucy');
    is($thing->friends->[1]->name,'Ethel');
  }
  
  $Pcursor = $autodb->find(-collection=>'Person');
  is($Pcursor->count,2);
  # delete the Person entries (Things refer to them)
  while (my $Person = $Pcursor->get_next) {
    $autodb->delete($Person);
  }
  
  # verify Person deletions
  is($Pcursor->count,0);
  
  ## make sure that search keys and serialized objects are really cleaned from the data store
  # test serialized objects -  only type 'Thing' should remain
  my $objs = $dbh->selectall_arrayref('select * from _AutoDB');
  for ( 0..@$objs-1 ) {
    my ($thaw,$obj) = undef;
    next unless $objs->[$_]->[0] =~ /[0-9]+/; # only select objects with oid's
    $obj = $objs->[$_]->[1];
    eval $obj; # sets the $thaw handle from list reference
    is(lc($thaw->{__proxy_for}), 'thing');
  }
  
  # test Person top-level search keys
  my $peeps = $dbh->selectall_arrayref('select * from Person');
  is($peeps->[0], undef, 'all Person top-level search keys are removed from the data store');
  
  # test Person list search keys - list keys are maintained in the data store -- this is subject to change
  my $peeps_list = $dbh->selectall_arrayref('select * from Person_friends');
  is($peeps_list->[0], undef, 'all Person list search keys are removed from the data store');
  
  $Tcursor->reset;
  # iterate over Tcursor collection
  while (my $thing = $Tcursor->get_next) {
    is(scalar @{$thing->friends}, 2, 'you can still see deleted objects through their referant\'s lists' );
    is($thing->friends->[0]->name,undef,'deleted object cannot be accessed through its search keys');
    is($thing->friends->[0]->sex,undef,'deleted object cannot be accessed through its search keys');
    is($thing->friends->[0]->friends,undef,'deleted object cannot be accessed through its search keys');  
    is($thing->friends->[1]->name,undef,'deleted object cannot be accessed through its search keys');
    is($thing->friends->[1]->sex,undef,'deleted object cannot be accessed through its search keys');
    is($thing->friends->[1]->friends,undef,'deleted object cannot be accessed through its search keys'); 
  }
  
  # find out if things are deleted before retrieving them
  $Tcursor->reset;
  while (my $thing = $Tcursor->get_next) {
    is(scalar @{$thing->friends}, 2, 'you can still see deleted objects through their referant\'s lists' );
    is($thing->is_deleted,0);
    # is_del <=> is_deleted (synonyms)
    is($thing->friends->[0]->is_del,1); # the only way to access Lucy
    is($thing->friends->[1]->is_deleted,1); # the only way to access Ethel
  }
}
