use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Scalar::Util;
use DBConnector;
use Class::AutoDB;
use Person;
no warnings; ## suppress unititialized variable warnings

my $DBC = new DBConnector;
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates4b tests a mix of implicit and explicit persistence of simple (having no list) 
# and compound (having a list) objects that were set up in testStorageStates4a

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
  
   my(%people);
  
  # get names and oid's
  my $rows = $dbh->selectall_arrayref('select object,name from Person');
  for ( 0..@$rows-1 ) {
    my ($name,$id) = undef;
    $people{ lc($rows->[$_]->[1]) } = $rows->[$_]->[0];
  }
  
  ## test Person search keys
  my($dawgs,$thaw,$list);
  # Joe no has friends (none that the data store knows about)
  my $j = $dbh->selectall_arrayref("select * from Person where object=$people{joe}");
  ok($j->[$_]->[0] == $people{joe});
  ok($j->[$_]->[1] eq q[Joe]);
  ok($j->[$_]->[2] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where object=$people{joe}");
  $list = $dawgs->[0]->[0];
  eval $list; # sets the $thaw handle from list reference
  is($thaw, undef, 'object persisted correctly at store() time');
  isnt($thaw->[0], $people{mary});
  isnt($thaw->[1], $people{bill});
  
  ($dawgs,$thaw,$list) = undef;
  
  # Mary has friends Joe, Bill
  my $m = $dbh->selectall_arrayref("select * from Person where object=$people{mary}");
  ok($m->[$_]->[0] == $people{mary});
  ok($m->[$_]->[1] eq q[Mary]);
  ok($m->[$_]->[2] eq q[female]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where object=$people{mary}");
  is($dawgs->[0]->[0], $people{joe});
  is($dawgs->[1]->[0], $people{bill});
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
  my $b = $dbh->selectall_arrayref("select * from Person where object=$people{bill}");
  ok($b->[$_]->[0] == $people{bill});
  ok($b->[$_]->[1] eq q[Bill]);
  ok($b->[$_]->[2] eq q[male]);
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where object=$people{bill}");
  is($dawgs->[0]->[0], $people{joe});
  is($dawgs->[1]->[0], $people{mary});
  # test persisted object's list
  ($thaw) = undef;
  my $b_obj = $dbh->selectall_arrayref("select object from _AutoDB where id=$people{bill}");
  eval $b_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 3, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
}
