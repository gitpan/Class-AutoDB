use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use YAML;
use Class::AutoDB::Serialize;
use testSerialize11;

# The testSerialize series tests Class::AutoDB::Serialize
# This test fetches a big list of objects stored by its companion test

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

  my $OBJECTS=5000;
  my $obj0=Class::AutoDB::Serialize->fetch($oid{'root'});
  my @objects=@{$obj0->list};
  ok(@objects==$OBJECTS,"root points to $OBJECTS objects");
  map {$_->id} @objects;	# fetch 'em
  ok(1,"fetched $OBJECTS objects");
  my $errors=0;
  for (my $i=0;$i<$OBJECTS;$i++) {
    my $obj=$objects[$i];
    my($prev,$next)=($obj->prev,$obj->next);
    $errors++ unless $obj->id==$i;
#    $errors++ unless $prev->id==($i-1)%$OBJECTS;
#    $errors++ unless $next->id==($i+1)%$OBJECTS;
    $errors++ unless $prev==$objects[($i-1)%$OBJECTS];
    $errors++ unless $next==$objects[($i+1)%$OBJECTS];
    
  }
  ok(!$errors,"examined $OBJECTS objects, $errors errors");
  
  untie %oid;
}
1;
