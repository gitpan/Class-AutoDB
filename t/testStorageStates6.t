use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Scalar::Util;
use DBConnector;
use Class::AutoDB;
use Person;
use Place;
use TestAutoDBOutside_1;
use TestAutoDBOutside_2;
use Error qw(:try);
no warnings; ## suppress unititialized variable warnings

my $DBC = new DBConnector(noclean=>0);
my $dbh = $DBC->getDBHandle;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates6 tests that outside objects (non-AutoDB objects) are not stored or referred to in object types
# or lists

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 

  # init inside objects
  my $joe=new Person(-name=>'Joe',-sex=>'male');
  my $eddy=new Person(-name=>'Eddy',-sex=>'male');
  
  # init outside objects
  my $out1 = new TestAutoDBOutside_1;
  $out1->this('siht');
  $out1->that('taht');
  $out1->other('rehto');
  my $out2 = new TestAutoDBOutside_2;
  $out2->this('siht');
  $out2->that('taht');
  $out2->other('rehto');
  
  # Set up friends lists
  $out1->{see_also} = $out2; # link outside objects together
  $out2->{see_also} = $out1;
  $joe->friends([$eddy, $out1]);
  $eddy->friends([$joe, $out2, 'string thing']);
  
  # lock AutoDB objects away
  $joe->store;
  $eddy->store;

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
  
  # joe
  my($dawgs,$thaw,$list);
  my $j = $dbh->selectall_arrayref("select * from Person where oid=$people{joe}");
  ok($j->[$_]->[0] == $people{joe});
  ok($j->[$_]->[1] eq q[Joe]);
  ok($j->[$_]->[3] eq q[male]);
  
  # test persisted object's list
  $dawgs = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{joe}");
  is($dawgs->[0]->[0], $people{eddy});
  is($dawgs->[2]->[0], undef, "outside object not added, as expected");
  # test persisted object
  ($thaw) = undef;
  my $j_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{joe}");
  eval $j_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 2, 'persisted object\'s list has anticipated number of list items' );
  # check that no list item is undef
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
  
  ($dawgs,$thaw,$list) = undef;
  
  # eddy
  my $e = $dbh->selectall_arrayref("select * from Person where oid=$people{eddy}");
  ok($e->[$_]->[0] == $people{eddy});
  ok($e->[$_]->[1] eq q[Eddy]);
  ok($e->[$_]->[3] eq q[male]);
  # test persisted object's list
  $dawgs = $dbh->selectall_hashref(qq/select friends from Person_friends where oid=$people{eddy}/,1);
  is(scalar keys %$dawgs, 2);
  ok(defined $dawgs->{$people{joe}});
  ok(defined $dawgs->{'string thing'});
  # test persisted object
  ($thaw) = undef;
  my $b_obj = $dbh->selectall_arrayref("select object from _AutoDB where oid=$people{eddy}");
  eval $b_obj->[0]->[0]; # sets the $thaw handle from object reference
  is(scalar @{$thaw->{friends}}, 3, 'persisted object\'s list has anticipated number of list items' );
  foreach my $item (@{$thaw->{friends}}) {
    isnt($item,undef,'list item is defined');
  }
}
1;