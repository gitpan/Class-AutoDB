# check requirements for running tests
# for some reason, test driver does not always ensure these guys exist, even though
# they are in 'build_requires'
#   - DBD::mysql
# check whether MySQl test database is accessible
use strict;
use Cwd;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Test::More;

# assert TAP version 13 support for pragmas to communicate results to TAP::Harness
# if requirements not met, no further tests will run, but results reported as PASS
print "TAP version 13\n";

# NG 13-07-29: use this code from 002.pod to avoid need to hardcode required versions
use t::Build;
my $builder=t::Build->current;
my $module=$builder->module_name;
my $version=$builder->dist_version;
diag("\nTesting $module $version, Perl $], $^X" );

# my $autobd_version=$builder->build_requires->{'Class::AutoDB'};
# my $dbd_version=$builder->build_requires->{'DBD::mysql'};
check_sdbm() or goto FAIL;

# CAUTION: may not work to put DBD::mysql in prereqs. 
#  in past, saw bug where if DBD::mysq not present, install tries to install 'DBD'
#  which does not exist
check_module('DBI') or goto FAIL;
check_module('DBD::mysql') or goto FAIL;

# before checking MySQL, generate database name and store in file
my $testdb="testdb$$";
my $file=File::Spec->catfile(qw(t testdb));
if (open(TESTDB,"> $file")) {
  print TESTDB "$testdb\n";
  close TESTDB;
} else {
  my $diag=<<DIAG
Unable to create file $file which contains test database name: $!
Test cannot proceed

DIAG
  ;
  diag($diag);
  goto FAIL;
}

check_mysql($testdb) or goto FAIL;

# since we got here, all requirements are met
pass('requirements are met');
done_testing();
exit();

FAIL:
print "pragma +stop_testing\n";
done_testing();


sub check_module {
  my($module,$version)=@_;
  defined $version or $version=$builder->build_requires->{$module};
  eval "use $module $version";
  if ($@) {
    my $diag= <<DIAG

These tests require that $module version $version or higher be installed. If the
test driver is unable to install the required module, it tries to run the test
anyway. This is futile in most cases and leads to the error detected here:

$@

DIAG
      ;
    diag($diag);
    return undef;
  }
  1;
}

# check whether MySQl test database is accessible
sub check_mysql {
  my $testdb=shift;
  # make sure we can talk to MySQL
  # NG 13-10-23: changed connect to use $ENV{USER} instead of undef. should be equivalent, but...
  my($dbh,$errstr);
  eval
    {$dbh=DBI->connect("dbi:mysql:",$ENV{USER},undef,
		       {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,})};
  $errstr=$@, goto FAIL if $@;
  goto FAIL unless $dbh;

  # NG 13-10-31: can no longer be lax about ability to create database since
  #  each test run creates unique database
  $dbh->do(qq(CREATE DATABASE IF NOT EXISTS $testdb)) or goto FAIL;
  $dbh->do(qq(USE $testdb)) or goto FAIL;

  # make sure we can do all necessary operations
  # create, alter, drop tables. insert, select, replace, update, select, delete
  # NG 10-11-19: ops on views needed for Babel, not AutoDB
  # NG 10-11-19: DROP tables and views if they exist
  $dbh->do(qq(DROP TABLE IF EXISTS test_table)) or goto FAIL;
  $dbh->do(qq(DROP VIEW IF EXISTS test_table)) or goto FAIL;
  $dbh->do(qq(DROP TABLE IF EXISTS test_view)) or goto FAIL;
  $dbh->do(qq(DROP VIEW IF EXISTS test_view)) or goto FAIL;

  $dbh->do(qq(CREATE TABLE test_table(xxx INT))) or goto FAIL;
  $dbh->do(qq(ALTER TABLE test_table ADD COLUMN yyy INT)) or goto FAIL;
  $dbh->do(qq(CREATE VIEW test_view AS SELECT * from test_table)) or goto FAIL;
  # do drop at end, since we need table here
  $dbh->do(qq(INSERT INTO test_table(xxx) VALUES(123))) or goto FAIL;
  $dbh->do(qq(SELECT * FROM test_table)) or goto FAIL;
  $dbh->do(qq(SELECT * FROM test_view)) or goto FAIL;
  $dbh->do(qq(REPLACE INTO test_table(xxx) VALUES(456))) or goto FAIL;
  $dbh->do(qq(UPDATE test_table SET yyy=789 WHERE xxx=123)) or goto FAIL;
  $dbh->do(qq(DELETE FROM test_table WHERE xxx=123)) or goto FAIL;
  $dbh->do(qq(DROP VIEW IF EXISTS test_view)) or goto FAIL;
  $dbh->do(qq(DROP TABLE IF EXISTS test_table)) or goto FAIL;
  # NG 13-09-15: print MySQL version to help track down subtle FAILs
  my $version=$dbh->selectrow_arrayref(qq(SELECT version())) or fail('get MySQL version');
  if ($version) {
    if (scalar(@$version)==1) {
      diag('Testing MySQL version '.$version->[0]." database $testdb");
    } else {
      fail('get MySQL version returned row with wrong number of columns. expected 1, got '.
	   scalar(@$version));
    }
  }
  # since we made it here, we can do everything!
  return 1;
 FAIL:
  $errstr or $errstr=DBI->errstr;
  my $diag=<<DIAG

These tests require that MySQL be running on 'localhost', that the user 
running the tests can access MySQL without a password, and with these
credentials, has sufficient privileges to (1) create a 'test' database, 
(2) create, alter, and drop tables in the 'test' database, (3) create and
drop views, and (4) run queries and updates on the database.

When verifying these capabilities, the test driver got the following
error message:

$errstr

DIAG
    ;
  diag($diag);
  undef;
}

# SDBM files created in t/SDBM directory
sub check_sdbm {
  my $errstr=_check_sdbm();
  return 1 unless $errstr;
  my $diag=<<DIAG

These tests require that the user running the tests can create and
access access SDBM files. When verifying these capabilities, the test
driver got the following error message:

$errstr

DIAG
    ;
  diag($diag);
  undef;
}
sub _check_sdbm {
  my $SDBM_dir=File::Spec->catdir(cwd(),qw(t SDBM));
  if (-e $SDBM_dir) {
    return "SDBM directory path $SDBM_dir exists but is not a directory" unless -d _;
    return "SDBM directory $SDBM_dir exists but is not readable" unless -r _;
    return "SDBM directory $SDBM_dir exists but is not writable" unless -w _;
  } else {			# try to make directory
    mkdir($SDBM_dir,0775) or return "Cannot create SDBM directory $SDBM_dir: $!";
  }
  # just test one SDBM file. if one works, we can assume all will work
  my $filebase='test';
  my $file=File::Spec->catfile($SDBM_dir,'test');
  my %hash;
  # first create it
  my $flags=O_TRUNC|O_CREAT|O_RDWR;
  my $tie=tie(%hash,'SDBM_File',$file,$flags,0666);
  return "Cannot create SDBM file $file: $!" unless $tie;
  $hash{test_key}='test_value';		# write something
  untie %hash;
  # reopen for read
  my $flags=O_RDWR;
  my $tie=tie(%hash,'SDBM_File',$file,$flags,0666);
  return "Cannot open SDBM file $file: $!" unless $tie;
  return "SDBM file $file not peristent" unless $hash{test_key} eq 'test_value';
  # since we made it here, we can do everything!
  undef;
}

