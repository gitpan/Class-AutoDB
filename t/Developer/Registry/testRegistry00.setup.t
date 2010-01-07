use t::lib;
use strict;
use Test::More;
use DBI;
use File::Basename;

# The testRegisty series tests Class::AutoDB::Registry
# This test sets up the database needed for later tests.
#
# This version assumes a fixed names for this database
#   TODO: allow database names to be set somehow

# NG 09-11-19: test.setup.sql creates empty _AutoDB. this doesn't work...
# my $sql=tify('test.setup.sql');
# system("mysql test < $sql"); # TODO: do this via Database component

system("mysql test -e 'drop table if exists _AutoDB;\'");

# make sure we can talk to MySQL and database exists
my $dbh=DBI->connect('dbi:mysql:database=test');
die "! Cannot connect to database: ".$dbh->errstr."\n".
  "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
      if $dbh->err;

pass('setup');			#just to quiet the test harness ;)

done_testing();
