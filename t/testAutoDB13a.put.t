use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Object;
use testAutoDB13;
use testAutoDB13a;

# The testAutoDB series tests Class::AutoDB

# create the database
my $autodb=new Class::AutoDB(-database=>'test',-create=>1);
my $dbh=$autodb->dbh;
my $tables=[qw(CollectionTop CollectionLeft CollectionRight CollectionBottom)];
test_create("create 1 collection, scalar and list keys of all types: create=>1",$tables);

sub test {
  my($obj,$testname,$top,$left,$right,$bottom)=@_;
  $obj->put;
  my $oid=$obj->oid;
  test1($oid,'top',$top,$testname);
  test1($oid,'left',$left,$testname);
  test1($oid,'right',$right,$testname);
  test1($oid,'bottom',$bottom,$testname);
}
sub test1 {
  my($oid,$what,$targets,$testname)=@_;
  my $table="Collection".ucfirst($what);
  my $column=lc($what).'_key';
  my @targets=map {[$oid,$_]} @{$targets||[]};
  my $sql="select oid,$column from $table where oid=$oid";
  my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
  is(scalar @$rows,scalar @targets,"$testname: $what count");
  cmp_deeply($rows,\@targets,"$testname: $what data");
}

# create objects
my $top_obj=new testAutoDBTop(-top_key=>'top object');
my $left_obj=new testAutoDBLeft(-top_key=>'top of left object',-left_key=>'left object');
my $right_obj=new testAutoDBRight(top_key=>'top of right object',-right_key=>'right object');
my $bottom_obj=new testAutoDBBottom
  (-top_key=>'top of bottom object',
   -left_key=>'left of bottom object',
   -right_key=>'right of bottom object',
   -bottom_key=>'bottom object');

test($top_obj,'top object',['top object']);
test($left_obj,'left object',['top of left object'],['left object']);
test($right_obj,'right object',['top of right object'],undef,['right object']);
test($bottom_obj,'bottom object',
     ['top of bottom object'],['left of bottom object'],['right of bottom object'],
     ['bottom object']);

