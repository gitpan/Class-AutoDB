package testAutoDB12;
use strict;
use DBI;
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

sub test_create {
  my($testname,$tables)=@_;
  my @tables=$tables? @$tables: [];
  push(@tables,'_AutoDB');	# built-in AutoDB table
  my $dbtables=$dbh->selectcol_arrayref(qq(show tables)); #  return ARRAY ref of table names
  my $table_set=new Set::Scalar(@tables);
  my $dbtable_set=new Set::Scalar(@$dbtables);
  ok($table_set->is_subset($dbtable_set),$testname);
}
*test_alter=\&test_create;

sub test_drop {
  my($testname,$tables)=@_;
  my @tables=$tables? @$tables: [];
  push(@tables,'_AutoDB');	# built-in AutoDB table
  my $dbtables=$dbh->selectcol_arrayref(qq(show tables)); #  return ARRAY ref of table names
  my $table_set=new Set::Scalar(@tables);
  my $dbtable_set=new Set::Scalar(@$dbtables);
  my $intersection=$table_set->intersection($dbtable_set);
  is_deeply($intersection,new Set::Scalar('_AutoDB'),$testname);
}
sub do_sql {
  for my $sql (@_) {
    $dbh->do($sql);
  }}

1;
