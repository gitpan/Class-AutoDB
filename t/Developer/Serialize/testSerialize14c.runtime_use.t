use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize14;
use testSerialize_RuntimeUse;
use testSerialize_RuntimeUseSubclass;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companions test fetching of objects
# whose class is not explicitly 'used'.  This tests
# code in Oid.pm that invokes 'use' at runtime. 
# This test (14c) and the next (14d) are regression tests for
# case in which subclass uses its parent via 'use base'. This
# creates a skeleton symbol table for parent class which caused
# Class::AutoDB::Oid::AUTOLOAD and stringify to not 'use' the 
# parent class.

my %oid;
SKIP: {
  # make sure databases exist
  my $dbh=DBI->connect('dbi:mysql:database=test');
  skip "! Cannot connect to database: ".$dbh->errstr."\n".
    "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
      if $dbh->err;
  my $tie=tie(%oid, 'SDBM_File', 'testSerialize.sdbm', O_RDWR, 0666);
  skip "! Cannot open SDBM file 'testSerialize.sdbm': ".$!."\n".
    "These tests require an SDBM file named 'testSerialize.sdbm'.  The user running the test must have permission to read and write this file."
      unless $tie;

  Class::AutoDB::Serialize->dbh($dbh);

  sub chain {
    my($prev,$next)=@_;
    $prev->next($next);
    $next->prev($prev);
  }
}

my $OBJECTS=5;
# make some objects. 
# 'fetch' program will explicitly 'use' class of root object,
#  but not class of nodes
my $root=new testSerialize(id=>0);
my @objects=($root,new testSerialize_RuntimeUseSubclass(id=>1),
	     map {new testSerialize_RuntimeUse(id=>$_)} (2..$OBJECTS-1));
# link into circular chain,
for (my $i=0;$i<$OBJECTS;$i++) {
  chain($objects[$i-1],$objects[$i]);
}
# and set 0-th object to point to all 
$objects[0]->list(\@objects);
  
ok(1,"created $OBJECTS objects");
map {$_->store} @objects;	# store them
$oid{'root'}=$objects[0]->oid;
ok(1,"stored $OBJECTS objects");

untie %oid;

done_testing();
