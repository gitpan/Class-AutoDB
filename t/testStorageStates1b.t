use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Scalar::Util;
use DBConnector;
use Class::AutoDB;
use Person;
no warnings; ## suppress unititialized variable warnings

my $DBC = new DBConnector( noclean => 0 );
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates1b tests the data that were installed in testStorageStates1a.t

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
  
   my(%people);
  
  # get names and oid's
  my $rows = $dbh->selectall_arrayref('select oid,name from Person');
  for ( 0..@$rows-1 ) {
    my ($name,$id) = undef;
    $people{ lc($rows->[$_]->[1]) } = $rows->[$_]->[0];
  }
  
  ## test Person search keys
  my($dawgs,$thaw,$list);
  # Joe has friends Mary, Bill
  my $j = $dbh->selectall_arrayref("select * from Person where oid=$people{joe}");
  ok($j->[$_]->[0] == $people{joe});
  ok($j->[$_]->[1] eq q[Joe]);
  ok($j->[$_]->[3] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{joe}");
  is($dawgs->[0]->[0], $people{mary});
  is($dawgs->[1]->[0], $people{bill});
  # test persisted object's list
  ($thaw) = undef;
  my $j_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{joe}");
  eval $j_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 2, 'persisted object\'s list has anticipated number of list items' );
  # check that no list item is undef
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
  
  ($dawgs,$thaw,$list) = undef;
  
  # Mary has friends Joe, Bill
  my $m = $dbh->selectall_arrayref("select * from Person where oid=$people{mary}");
  ok($m->[$_]->[0] == $people{mary});
  ok($m->[$_]->[1] eq q[Mary]);
  ok($m->[$_]->[3] eq q[female]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{mary}");
  is($dawgs->[0]->[0], $people{joe});
  is($dawgs->[1]->[0], $people{bill});
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
  my $b = $dbh->selectall_arrayref("select * from Person where oid=$people{bill}");
  ok($b->[$_]->[0] == $people{bill});
  ok($b->[$_]->[1] eq q[Bill]);
  ok($b->[$_]->[3] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{bill}");
  $list = $dawgs->[0]->[0];
  eval $list; # sets the $thaw handle from list reference
  is($dawgs->[0]->[0], $people{joe});
  is($dawgs->[1]->[0], $people{mary});
  # test persisted object's list
  ($thaw) = undef;
  my $b_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{bill}");
  eval $b_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 3, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
}
