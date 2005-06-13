use strict;
use Class::AutoDB;
use Test::More qw/no_plan/;
use Set::Scalar;
use Class::AutoDB::Object;
use testAutoDB14;

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
my $autodb=new Class::AutoDB(-database=>'test',-create=>1);
my $dbh=$autodb->dbh;
my $tables=[qw(Person)];
test_create("create Person: create=>1",$tables);

my $joe=new Person(-name=>'Joe',-sex=>'male');
my $mary=new Person(-name=>'Mary',-sex=>'female');
my $bill=new Person(-name=>'Bill',-sex=>'male');
# Set up friends lists
$joe->friends([$mary,$bill]);
$mary->friends([$joe,$bill]);
$bill->friends([$joe,$mary]);

# TODO: get rid of put's once auto-put is working
$joe->put;
$mary->put;
$bill->put;

ok(1,'end of test');
