use strict;
use lib qw(. t ../lib);
use Class::AutoDB;
use AnotherPerson;
use Test::More qw/no_plan/;
use DBConnector;

## the testStorageStatesX (where X is an integer) series of tests puts AutoDB through a bunch of storage scenarios, 
## using both explicit (calling the store method on an object) and implicit (letting an object fall out of scope 
## and be automatically written) methods of persistence.

# testStorageStates7b tests that items which AutoClass keys do not get stored where they are not also AutoDB keys.
# These were set up in testStorageStates7a.

my $DBC = new DBConnector();
my $dbh = $DBC->getDBHandle;


SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
        
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
  
   my(%people);
  
  # get names and oid's
  my $rows = $dbh->selectall_arrayref('select oid,name from Person'); # class AnotherPerson is in the Person colection
  for ( 0..@$rows-1 ) {
    my ($name,$id) = undef;
    $people{ lc($rows->[$_]->[1]) } = $rows->[$_]->[0];
  }
  
  ## test Joe ##
  # test AnotherPerson search keys
  my($hobs,$peeps,$thaw,$list);
  my $j = $dbh->selectall_hashref("select * from Person where oid=$people{joe}",1);
  is(scalar keys %{$j->{$people{joe}}}, 3); # object id and two possible keys for AnotherPerson
  ok(defined $j->{$people{joe}}->{name});
  ok(defined $j->{$people{joe}}->{sex});
  $hobs = $dbh->selectall_hashref("select hobbies from Person_hobbies where oid=$people{joe}",1);
  is(scalar keys %{$hobs}, 2); # object id and two possible keys for AnotherPerson
  ok(defined $hobs->{'mountain climbing'});
  ok(defined $hobs->{'sailing'});
  $peeps = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{joe}");
  is($peeps, undef, 'friend\'s list not stored (expected, it is not an AutoDB key)');
  
  ($hobs,$peeps,$thaw,$list) = undef;
  
  ## test Mary ##
  # test AnotherPerson search keys
  my $m = $dbh->selectall_hashref("select * from Person where oid=$people{mary}",1);
  is(scalar keys %{$m->{$people{mary}}}, 3); # object id and two possible keys for AnotherPerson
  ok(defined $m->{$people{mary}}->{name});
  ok(defined $m->{$people{mary}}->{sex});
  $hobs = $dbh->selectall_hashref("select hobbies from Person_hobbies where oid=$people{mary}",1);
  ok(defined $hobs->{'hang gliding'});
  $peeps = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{mary}");
  is($peeps, undef, 'friend\'s list not stored (expected, it is not an AutoDB key)');

  ($hobs,$peeps,$thaw,$list) = undef;
  
  ## test Bill ##
  # test AnotherPerson search keys
  my $b = $dbh->selectall_hashref("select * from Person where oid=$people{bill}",1);
  is(scalar keys %{$b->{$people{bill}}}, 3); # object id and two possible keys for AnotherPerson
  ok(defined $b->{$people{bill}}->{name});
  ok(defined $b->{$people{bill}}->{sex});
  $hobs = $dbh->selectall_hashref("select hobbies from Person_hobbies where oid=$people{bill}",1);
  is(scalar keys %{$b->{$hobs}}, 0); # boring billhas no hobbies
  $peeps = $dbh->selectall_arrayref("select friends from Person_friends where oid=$people{bill}");
  is($peeps, undef, 'friend\'s list not stored (expected, it is not an AutoDB key)');
}
