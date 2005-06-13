use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB;
use Class::AutoDB::Serialize;
use testAutoDB11;
use testAutoDB11a;

# The testAutoDB series tests Class::AutoDB::AutoDB

# create the database
my $tables=[qw(Collection)];
start($tables);
my $autodb=new Class::AutoDB(-database=>'test',-create=>1);
test_create("create 1 collection, scalar and list keys of all types: create=>1",$tables);

# store some data "by hand"
my $obj=new testAutoDB
  (skey1=>'string1',skey2=>12,skey3=>1.2,
   lkey1=>['string1','string2'],
   lkey2=>[12,34,56],
   lkey3=>[1.2],
  );
$obj->skey4($obj);
$obj->lkey4([$obj]);
$obj->store;			# store serialized form
my $oid=$obj->oid;

my $dbh=$autodb->dbh;
my @sql;
push(@sql,qq(insert into Collection(skey1, skey2, skey3, skey4, oid) 
	     values('string1',12,1.2,$oid,$oid)));
push(@sql,qq(insert into Collection_lkey1(lkey1,oid) values('string1',$oid),('string2',$oid)));
push(@sql,qq(insert into Collection_lkey2(lkey2,oid) values(12,$oid),(34,$oid),(56,$oid)));
push(@sql,qq(insert into Collection_lkey3(lkey3,oid) values(1.2,$oid)));
push(@sql,qq(insert into Collection_lkey4(lkey4,oid) values($oid,$oid)));
do_sql($dbh,@sql);

sub test {
  my($testname,$targets,@find)=@_;
  $targets or $targets=[];
  # Do it using get all
  my $results;
  my $cursor=$autodb->find(@find);
  @$results=$cursor->get;
  is(scalar @$results,scalar @$targets,"$testname: get: number of objects");
  is_shallow($results,$targets,"$testname: get: objects");
  # Do it again using get_next
  $results=[];
  my $cursor=$autodb->find(@find);
  while(my $result=$cursor->get_next) {
    push(@$results,$result);
  }
  is(scalar @$results,scalar @$targets,"$testname: get_next: number of objects");
  is_shallow($results,$targets,"$testname: get_next: objects");
}
sub is_shallow {
  my($results,$targets,$tag)=@_;
  my(%results,%targets);
  @results{@$results}=@$results;
  @targets{@$targets}=@$targets;
  my $ok=
    (scalar(keys %results)==scalar(keys %targets) &&
     scalar(grep {$targets{$_}} keys %results)==keys %results);
  ok($ok,$tag);
}
sub do_sql {
  my $dbh=shift;
  for my $sql (@_) {
    $dbh->do($sql);
    diag($dbh->errstr) if $dbh->err;
    ok(!$dbh->err,"SQL")
  }}

# tests start here
# do some find/get operations
test('Collection',[$obj], -collection=>'Collection');

# test scalar keys
test('Collection where skey1',[$obj],
     -collection=>'Collection',skey1=>'string1');
test('Collection where skey1,skey2',[$obj],
     -collection=>'Collection',skey1=>'string1',skey2=>12);
test('Collection where skey1,skey2,skey3',[$obj],
     -collection=>'Collection',skey1=>'string1',skey2=>12,skey3=>1.2);
test('Collection where skey1,skey2,skey3,skey4',[$obj],
     -collection=>'Collection',skey1=>'string1',skey2=>12,skey3=>1.2,skey4=>$obj);
test('Collection where false',undef, # this one should get nothing
     -collection=>'Collection',skey1=>'string1',skey2=>12,skey3=>0);

# test list keys
test('Collection where lkey1',[$obj],
     -collection=>'Collection',lkey1=>'string1');
test('Collection where lkey1,lkey2',[$obj],
     -collection=>'Collection',lkey1=>'string1',lkey2=>12);
test('Collection where lkey1,lkey2,lkey3',[$obj],
     -collection=>'Collection',lkey1=>'string1',lkey2=>12,lkey3=>1.2);
test('Collection where lkey1,lkey2,lkey3,lkey4',[$obj],
     -collection=>'Collection',lkey1=>'string1',lkey2=>12,lkey3=>1.2,lkey4=>$obj);
test('Collection where false',undef, # this one should get nothing
     -collection=>'Collection',lkey1=>'string1',lkey2=>12,lkey3=>0);

# test all
test('Collection where skey1,skey2,skey3,skey4,lkey1,lkey2,lkey3,lkey4',[$obj],
     -collection=>'Collection',
     skey1=>'string1',skey2=>12,skey3=>1.2,skey4=>$obj,
     lkey1=>'string1',lkey2=>12,lkey3=>1.2,lkey4=>$obj);
