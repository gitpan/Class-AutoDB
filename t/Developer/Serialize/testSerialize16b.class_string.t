use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize16;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companions test overloading of the
# stringify operator and related operators 'eq' and 'ne'
# This test code in Oid.pm

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
}
my $obj=Class::AutoDB::Serialize->fetch($oid{'obj'});
ok(!ref $obj->class_string,'fetched string is scalar');
is($obj->class_string,'testSerialize','fetched string has expected value');

untie %oid;

1;

done_testing();
