use strict;
no warnings;
use Module::Build;
use File::Spec;
use Cwd qw(cwd);
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;

use lib qw(t);
use t::Build;			# my Module::Build subclass
my $class='t::Build';
# TODO: database name should be configurable
# CAUTION: $test_db and $SDBM_dir duplicated in t/autodbUtil.pm
our $test_db='test';
our $SDBM_dir=File::Spec->catdir(cwd(),qw(t SDBM));

my $builder = $class->new
  (module_name         => 'Class::AutoDB',
   license             => 'perl',
   dist_author         => q{Nat Goodman <natg@shore.net>},
   configure_requires=>{'Cwd' => 3.26,
			# 'DBD::mysql' => 4.007,
			'DBI' => 1.604,
			'File::Spec' => 3.26,
			'SDBM_File' => 0,
			},
   build_requires =>   {'Carp' => 0,
			'Class::AutoClass' => 1.53,
			'Config' => 0,
			'Cwd' => 3.26,
			'DBD::mysql' => 4.007,
			'DBI' => 1.604,
			'Data::Rmap' => 0.61,
			'Exporter' => 5.58,
			'ExtUtils::CBuilder' => 0.22,
			'File::Basename' => 0,
			'File::Spec' => 3.26,
			'File::Spec::Functions' => 3.26,
			'FindBin' => 0,
			'Getopt::Long' => 2.13,
			'Hash::AutoHash::Args' => 1.11,
			'List::MoreUtils' => 0.09,
			'List::Util' => 1.14,
			'SDBM_File' => 0,
			'Scalar::Util' => 1.01,
			'Storable' => 2.16,
			'TAP::Harness' => 3.12,
			'Test::Deep' =>  0.098,
			'Test::More' => 0.88,
		       },
   requires =>         {'Carp' => 0,
			'Class::AutoClass' => 1.54,
			'Class::Singleton' => 1.04,
			# 'DBD::mysql' => 4.007,
			'DBI' => 1.604,
			'Hash::AutoHash::Args' => 1.11,
			'Scalar::Util' => 1.01,
			'Storable' => 2.16,
			'Text::Abbrev' => 1.01,	
			'Tie::ToObject' => 0.03,
		       },
   add_to_cleanup      => [ 'Class-AutoDB-*',
			    File::Spec->catfile($SDBM_dir,'*') , '*.dir', '*.pag' ],
   create_makefile_pl => 'small',
   extra_compiler_flags => ['-DUSE_PPPORT_H'],
   use_tap_harness => 1,			  
   test_files => 't/autodb.*.t',
);

# not possible to run tests unless MySQL available on 'localhost', and 
#   current user has enough privileges to do everything we need. 
# while we're at it, we might as well also check that SDBM files can be
#   created (although it's hard to imagine this failing)
# the experts recommend checking such requirements here (in Build.PL).
#   if tests cannot proceed, do not create Build and exit(0).
#   automated CPAN testers will report this as status UNKNOWN 
#   in this case, the test report will also include anything we print

my $ok=1;
my $mysql_errstr=chk_mysql() and $ok=0;
my $sdbm_errstr=chk_sdbm() and $ok=0;
  print <<EOS
These tests require that MySQL be running on 'localhost', that the
user running the tests can access MySQL without a password, and with
these credentials, has sufficient privileges to (1) create a 'test'
database, (2) create, alter, and drop tables in the 'test' database,
and (3) run queries and updates on the database.

When verifying these capabilities, the test driver got the following
error message:

$mysql_errstr
EOS
  if $mysql_errstr;

  print <<EOS

These tests require that the user running the tests can create and
access access SDBM files. When verifying these capabilities, the test
driver got the following error message:

$sdbm_errstr
EOS
  if $sdbm_errstr;

exit(0) unless $ok;		# do not create Build script unless tests can run

$builder->create_build_script();

# check whether MySQl test database is accessible
# return error string if not
sub chk_mysql {
  # NG 11-01-07: added checks below from Data::Babel Build script
  # make sure DBD::mysql is available. doesn't work to put in prereqs because
  #  if not present, install tries to install 'DBD' which does not exist
  # eval {use DBD::mysql 4.007};
  eval "use DBD::mysql 4.007";
  return "DBD::mysql not available:\n$@" if $@;

  # make sure we can talk to MySQL
  my $dbh;
  eval
    {$dbh=DBI->connect("dbi:mysql:",undef,undef,
		       {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,})};
  return $@ if $@;
  return $DBI::errstr unless $dbh;

  # try to create database if necessary, then use it
  # don't worry about create-errors: may be able to use even if can't create
  $dbh->do(qq(CREATE DATABASE IF NOT EXISTS $test_db));
  $dbh->do(qq(USE $test_db)) or return $dbh->errstr;

  # make sure we can do all necessary operations
  # create, alter, drop tables. insert, select, replace, update, select, delete
  $dbh->do(qq(CREATE TABLE IF NOT EXISTS test(xxx INT))) or return $dbh->errstr;
  $dbh->do(qq(ALTER TABLE test ADD COLUMN yyy INT)) or return $dbh->errstr;
  # do drop at end, since we need table here
  $dbh->do(qq(INSERT INTO test(xxx) VALUES(123))) or return $dbh->errstr;
  $dbh->do(qq(SELECT * FROM test)) or return $dbh->errstr;
  $dbh->do(qq(REPLACE INTO test(xxx) VALUES(456))) or return $dbh->errstr;
  $dbh->do(qq(UPDATE test SET yyy=789 WHERE xxx=123)) or return $dbh->errstr;
  $dbh->do(qq(DELETE FROM test WHERE xxx=123)) or return $dbh->errstr;
  $dbh->do(qq(DROP TABLE IF EXISTS test)) or return $dbh->errstr;
  # since we made it here, we can do everything!
  undef;
}

# SDBM files created in t/SDBM directory
sub chk_sdbm {
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
