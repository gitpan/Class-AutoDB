use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Scalar::Util;
use DBConnector;
use Class::AutoDB;
use Person;
no warnings; ## suppress unititialized variable warnings

my $DBC = new DBConnector();
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates5 tests a mix of implicit and explicit persistence of compound (having a list) objects and
# tests that list members are set correctly

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 

  
  my $joe=new Person(-name=>'Joe',-sex=>'male');
  my $mary=new Person(-name=>'Mary',-sex=>'female');
  my $bill=new Person(-name=>'Bill',-sex=>'male');
  
  my $jid = $joe->{__object_id};
  my $mid = $mary->{__object_id};
  my $bid = $bill->{__object_id};
  
  #
  # Set up friends lists
  #
  $joe->friends([$mary,$bill]);
  $joe->name("joey");
  $joe->store;
  
  # changes to joe after a manual store should not make their way into the persisted object
  $joe->friends([$mary,$bill,"someone less important"]);
  $mary->friends([$joe,$bill]);
  $bill->friends([$joe,$mary,'a doll named sue']);
  
  $mary->store;
  $bill->store;
  
  # implicitly store all (joe already stored explicitly by calling the store() method)
  Scalar::Util::weaken($bill);
  Scalar::Util::weaken($joe);
  Scalar::Util::weaken($mary);

  #
  ## compare inserts with expected results
  #
  my(%people);
  
  # get names and oid's
  my $rows = $dbh->selectall_arrayref('select oid,name from Person');
  for ( 0..@$rows-1 ) {
    my ($name,$id) = undef;
    $people{ lc($rows->[$_]->[1]) } = $rows->[$_]->[0];
  }
  
  ## test Person search keys
  my($dawgs,$thaw,$list);
  my $j = $dbh->selectall_arrayref("select * from Person where oid=$jid");
  ok($j->[$_]->[0] == $jid);
  ok($j->[$_]->[1] eq q[joey]);
  ok($j->[$_]->[3] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$jid");
  is($dawgs->[0]->[0], $mid);
  is($dawgs->[1]->[0], $bid);
  is($dawgs->[2]->[0], undef); # list item was added implicitly after an explicit store
  # test persisted object's list
  ($thaw) = undef;
  my $j_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{joey}");
  eval $j_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 2, 'persisted object\'s list has anticipated number of list items' );
  # check that no list item is undef
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
  
  ($dawgs,$thaw,$list) = undef;
  
  # Mary has friends Joe, Bill
  my $m = $dbh->selectall_arrayref("select * from Person where oid=$mid");
  ok($m->[$_]->[0] == $mid);
  ok($m->[$_]->[1] eq q[Mary]);
  ok($m->[$_]->[3] eq q[female]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$mid");
  is($dawgs->[0]->[0], $jid);
  is($dawgs->[1]->[0], $bid);
  # test persisted object's list
  ($thaw) = undef;
  my $m_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{mary}");
  eval $m_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 2, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
  
  ($dawgs,$thaw,$list) = undef;
  
  # Bill has friends Joe, Mary
  my $b = $dbh->selectall_arrayref("select * from Person where oid=$bid");
  ok($b->[$_]->[0] == $bid);
  ok($b->[$_]->[1] eq q[Bill]);
  ok($b->[$_]->[3] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$bid");
  is($dawgs->[0]->[0], $jid);
  is($dawgs->[1]->[0], $mid);
  # test persisted object's list
  ($thaw) = undef;
  my $b_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{bill}");
  eval $b_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 3, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
}
