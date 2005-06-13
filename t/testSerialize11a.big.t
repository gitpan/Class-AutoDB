use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize11;

# The testSerialize series tests Class::AutoDB::Serialize
# This test stores a big list of objects
# for later fetch by its companion testSerialize1b.t

SKIP: {
  # make sure databases exist
  my $dbh=DBI->connect('dbi:mysql:database=test');
  skip "! Cannot connect to database: ".$dbh->errstr."\n".
    "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
      if $dbh->err;
  my %oid;
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

  my $OBJECTS=5000;
  # make some objects
  my @objects=map {new testSerialize(id=>$_)} (0..$OBJECTS-1);
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
}

