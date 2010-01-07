use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize16;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companions are regression test for object
# containing a string whose value matches the name of a 
# Class::AutoDB::Serialize subclass. The bug was that 
# Serialize::store stored this as Oid, rather than a string.

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

my $obj=new testSerialize(-class_string=>'testSerialize');
isa_ok($obj,'Class::AutoDB::Serialize','test object');
$obj->store;
$oid{obj}=$obj->oid;
ok(1,"stored object");

untie %oid;

done_testing();
