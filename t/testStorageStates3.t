use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use DBConnector;
use Class::AutoDB;
use Person;
no warnings; ## suppress unititialized variable warnings## suppress unititialized varibale warnings

my $DBC = new DBConnector;
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates3 specifically tests explicit persistence of compound (having a list) objects

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
  
  # Set up friends lists
  $joe->friends([$mary,$bill]);
  $mary->friends([$joe,$bill]);
  $bill->friends([$joe,$mary,'a doll named sue']);

  # explicitly store objects
  $joe->store;
  $bill->store;
  $mary->store;

  #
  ## compare inserts with expected results
  #
  my(%people);
  
  # get names and oid's
  my $rows = $dbh->selectall_arrayref('select object,name from Person');
  for ( 0..@$rows-1 ) {
    my ($name,$id) = undef;
    $people{ lc($rows->[$_]->[1]) } = $rows->[$_]->[0];
  }
  
  ## test person search keys
  my($dawgs,$thaw,$list);
  # Joe has friends Mary, Bill
  my $j = $dbh->selectall_arrayref("select * from Person where object=$jid");
  ok($j->[$_]->[0] == $jid);
  ok($j->[$_]->[1] eq q[Joe]);
  ok($j->[$_]->[2] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where object=$jid");
  $list = $dawgs->[0]->[0];
  eval $list; # sets the $thaw handle from list reference
  is($thaw->[0], $mid);
  is($thaw->[1], $bid);
   # test persisted object's list
  ($thaw) = undef;
  my $j_obj = $dbh->selectall_arrayref("select object from _AutoDB where id=$people{joe}");
  eval $j_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 2, 'persisted object\'s list has anticipated number of list items' );
  # check that no list item is undef
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
  
  ($dawgs,$thaw,$list) = undef;
  
  # Mary has friends Joe, Bill
  my $m = $dbh->selectall_arrayref("select * from Person where object=$mid");
  ok($m->[$_]->[0] == $mid);
  ok($m->[$_]->[1] eq q[Mary]);
  ok($m->[$_]->[2] eq q[female]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where object=$mid");
  $list = $dawgs->[0]->[0];
  eval $list; # sets the $thaw handle from list reference
  is($thaw->[0], $jid);
  is($thaw->[1], $bid);
  # test persisted object's list
  ($thaw) = undef;
  my $m_obj = $dbh->selectall_arrayref("select object from _AutoDB where id=$people{mary}");
  eval $m_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 2, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
  
  ($dawgs,$thaw,$list) = undef;
  
  # Bill has friends Joe, Mary
  my $b = $dbh->selectall_arrayref("select * from Person where object=$bid");
  ok($b->[$_]->[0] == $bid);
  ok($b->[$_]->[1] eq q[Bill]);
  ok($b->[$_]->[2] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where object=$bid");
  $list = $dawgs->[0]->[0];
  eval $list; # sets the $thaw handle from list reference
  is($thaw->[0], $jid);
  is($thaw->[1], $mid);
  # test persisted object's list
  ($thaw) = undef;
  my $b_obj = $dbh->selectall_arrayref("select object from _AutoDB where id=$people{bill}");
  eval $b_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 3, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
}
