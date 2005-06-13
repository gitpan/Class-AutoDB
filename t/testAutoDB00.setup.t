use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;

# The testAutoDB series tests Class::AutoDB::AutoDB
# This test sets up the databases needed for the tests
#   1) a MySQL database to hold the objects created by the test programs
#   2) SDBM file to hold test information shared between test programs
# This version assumes fixed names for these datbases.
#   TODO: allow database names to be set somehow

# make sure we can talk to MySQL and database exists
my $dbh=DBI->connect('dbi:mysql:database=test');
die "! Cannot connect to database: ".$dbh->errstr."\n".
  "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
  if $dbh->err;

my %table2counter;
my $tie=tie(%table2counter, 'SDBM_File', 'testAutoDB_counter.sdbm', O_TRUNC|O_CREAT, 0666);
die "! Cannot open SDBM file 'testAutoDB_counter.sdbm': ".$!."\n".
  "These tests require an SDBM file named 'testAutoDB_counter.sdbm'.  The user running the test must have permission to read and write this file."
  unless $tie;
untie %table2counter;
  
is(1,1); #just to quiet the test harness ;)e
1;
