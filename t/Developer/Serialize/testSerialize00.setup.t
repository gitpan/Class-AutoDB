use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use File::Basename;

# The testSerialize series tests Class::AutoDB::Serialize
# This test sets up the databases needed for later tests.
# Three databases are needed:
#   1) a MySQL database to hold the objects created by the test programs
#   2,3) SDBM files to hold test information shared between test programs
# This version assumes fixed names for these datbases.
#   TODO: allow database names to be set somehow

# my $sql=tify('test.setup.sql');
# system("mysql test < $sql"); # TODO: do this via Database component

my $sql=<<SQL
drop table if exists _AutoDB;
create table _AutoDB (
  oid bigint unsigned not null,
  object longblob,
  primary key (oid)
);
SQL
;
system("mysql test -e '$sql'"); # TODO: do this via Database component

SKIP: {
  # make sure we can talk to MySQL and database exists
  my $dbh=DBI->connect('dbi:mysql:database=test');
  skip "! Cannot connect to database: ".$dbh->errstr."\n".
    "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
      if $dbh->err;
  my %oid;
  my $tie=tie(%oid, 'SDBM_File', 'testSerialize.sdbm', O_TRUNC|O_CREAT, 0666);
  skip "! Cannot create SDBM file 'testSerialize.sdbm': ".$!."\n".
    "These tests require an SDBM file named 'testSerialize.sdbm'.  The user running the test must have permission to create, delete, read and write this file."
      unless $tie;
  untie %oid;
  my %oid2counter;
  my $tie=tie(%oid2counter, 'SDBM_File', 'testSerialize_counter.sdbm', O_TRUNC|O_CREAT, 0666);
  skip "! Cannot open SDBM file 'testSerialize_counter.sdbm': ".$!."\n".
    "These tests require an SDBM file named 'testSerialize_counter.sdbm'.  The user running the test must have permission to read and write this file."
      unless $tie;
  untie %oid2counter;
  
}
pass('setup');			#just to quiet the test harness ;)

done_testing();
