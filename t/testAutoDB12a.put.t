use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Object;
use testAutoDB12;
use testAutoDB12a;

# The testAutoDB series tests Class::AutoDB

# create the database
my $autodb=new Class::AutoDB(-database=>'test',-create=>1);
my $tables=[qw(Collection)];
test_create("create 1 collection, scalar and list keys of all types: create=>1",$tables);

# create an object and 'put' it
my $obj=new testAutoDB
  (skey1=>'string1',skey2=>12,skey3=>1.2,
   lkey1=>['string1'],
   lkey2=>[12,34],
   lkey3=>[1.2,3.4,5.6],
  );
$obj->skey4($obj);
$obj->lkey4([$obj,$obj,$obj,$obj]);
$obj->put;

# see if it's there using SQL
my $oid=$obj->oid;
my $dbh=$autodb->dbh;
my @sql;

my $sql="select oid,skey1,skey2,skey3 from Collection";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,1,"Collection count");
is_deeply($rows->[0],[$oid,'string1',12,1.2],"Collection data");

# test list tables
my $sql="select oid,lkey1 from Collection_lkey1";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,1,"Collection_lkey1 count");
cmp_bag($rows,[[$oid,'string1']],"Collection_lkey1 data");

my $sql="select oid,lkey2 from Collection_lkey2";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,2,"Collection_lkey2 count");
cmp_bag($rows,[[$oid,12],[$oid,34]],"Collection_lkey2 data");

my $sql="select oid,lkey3 from Collection_lkey3";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,3,"Collection_lkey3 count");
cmp_bag($rows,[[$oid,1.2],[$oid,3.4],[$oid,5.6]],"Collection_lkey3 data");

my $sql="select oid,lkey4 from Collection_lkey4";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,4,"Collection_lkey4 count");
cmp_bag($rows,[[$oid,$oid],[$oid,$oid],[$oid,$oid],[$oid,$oid]],"Collection_lkey4 data");

# change object and re-put it
$obj->skey1('changed string1');
$obj->skey2(34);
$obj->skey3(3.4);
$obj->skey4(undef);
$obj->lkey1(['changed string1','changed string2']);
$obj->lkey2([56,78,90]);
$obj->lkey3([5.6,7.8,9.10,11.12]);
$obj->lkey4([]);
$obj->put;

my $sql="select oid,skey1,skey2,skey3 from Collection";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,1,"changed Collection count");
is_deeply($rows->[0],[$oid,'changed string1',34,3.4],"changed Collection data");

# test list tables
my $sql="select oid,lkey1 from Collection_lkey1";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,2,"Collection_lkey1 count");
cmp_bag($rows,[[$oid,'changed string1'],[$oid,'changed string2']],"Collection_lkey1 data");

my $sql="select oid,lkey2 from Collection_lkey2";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,3,"Collection_lkey2 count");
cmp_bag($rows,[[$oid,56],[$oid,78],[$oid,90]],"Collection_lkey2 data");

my $sql="select oid,lkey3 from Collection_lkey3";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,4,"Collection_lkey3 count");
cmp_bag($rows,[[$oid,5.6],[$oid,7.8],[$oid,9.10],[$oid,11.12]],"Collection_lkey3 data");

my $sql="select oid,lkey4 from Collection_lkey4";
my $rows=$dbh->selectall_arrayref($sql) || die $dbh->errstr;
is(scalar @$rows,0,"Collection_lkey4 count");
cmp_bag($rows,[],"Collection_lkey4 data");
