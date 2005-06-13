package testAutoDB02;
use strict;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Set::Scalar;
use Test::More;
use Exporter();
our @ISA=qw(Exporter);
our @EXPORT=qw(start test_create test_drop test_alter);

# make sure we can talk to MySQL and database exists
our $dbh=DBI->connect('dbi:mysql:database=test');
die "! Cannot connect to database: ".$dbh->errstr."\n".
  "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
  if $dbh->err;

our %table2counter;
my $tie=tie(%table2counter, 'SDBM_File', 'testAutoDB_counter.sdbm', O_RDWR, 0666);
die "! Cannot open SDBM file 'testAutoDB_counter.sdbm': ".$!."\n".
  "These tests require an SDBM file named 'testAutoDB_counter.sdbm'.  The user running the test must have permission to read and write this file."
  unless $tie;

sub test_create {
  my($testname,$tables)=@_;
  my @tables=$tables? @$tables: [];
  push(@tables,'_AutoDB');	# built-in AutoDB table
  my $dbtables=$dbh->selectcol_arrayref(qq(show tables)); #  return ARRAY ref of table names
  my $table_set=new Set::Scalar(@tables);
  my $dbtable_set=new Set::Scalar(@$dbtables);
  ok($table_set->is_subset($dbtable_set),$testname);
}
sub test_drop {			# after drop, tables should not exist
  my($testname,$tables)=@_;
  my @tables=$tables? @$tables: [];
  push(@tables,'_AutoDB');	# built-in AutoDB table
  my $dbtables=$dbh->selectcol_arrayref(qq(show tables)); #  return ARRAY ref of table names
  my $table_set=new Set::Scalar(@tables);
  my $dbtable_set=new Set::Scalar(@$dbtables);
  my $intersection=$table_set->intersection($dbtable_set);
  is_deeply($intersection,new Set::Scalar('_AutoDB'),$testname);
}
sub test_alter {
  my($testname,$tables)=@_;
  my @tables=$tables? @$tables: [];
  push(@tables,'_AutoDB');	# built-in AutoDB table
  my $dbtables=$dbh->selectcol_arrayref(qq(show tables)); #  return ARRAY ref of table names
  my $table_set=new Set::Scalar(@tables);
  my $dbtable_set=new Set::Scalar(@$dbtables);
  ok($table_set->is_subset($dbtable_set),$testname);
  # check data content
  for my $table (@$tables) {
    my $counter=$table2counter{$table}||0;
    my($t_counter)=$dbh->selectrow_array(qq(select count(*) from $table));
    is($t_counter,$counter,"$testname: $table count=$counter");
    $counter++;
    $dbh->do(qq(insert into $table (oid) values($counter)));
    # Make sure the insert worked
    my($t_counter)=$dbh->selectrow_array(qq(select count(*) from $table));
    die "insert failed: ".qq(select count(*) from $table) unless $t_counter==$counter;
    $table2counter{$table}=$counter;
  }
}
sub do_sql {
  for my $sql (@_) {
    $dbh->do($sql);
  }}

1;
