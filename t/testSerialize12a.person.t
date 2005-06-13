use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize12;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companion implement the 'person' example
# from the docs

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

  my $joe=new Person(-name=>'Joe',-sex=>'male',
  		     -hobbies=>['mountain climbing', 'sailing']);
  my $mary=new Person(-name=>'Mary',-sex=>'female',
		      -hobbies=>['hang gliding']);
  my $bill=new Person(-name=>'Bill',-sex=>'male',
                      -hobbies=>['cooking', 'eating', 'sleeping']);
  
  # Set up friends lists
  $joe->friends([$mary,$bill]);
  $mary->friends([$joe,$bill]);
  $bill->friends([$joe,$mary]);

  # Store the objects
  $joe->store;
  $mary->store;
  $bill->store;

  $oid{'joe'}=$joe->oid;
  $oid{'mary'}=$mary->oid;
  $oid{'bill'}=$bill->oid;
  ok(1,"created and stored person objects");
  untie %oid;
}

