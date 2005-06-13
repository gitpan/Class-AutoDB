use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Object;
use testAutoDB12;
use testAutoDB12a;

# The testAutoDB series tests Class::AutoDB

my $autodb=new Class::AutoDB(-database=>'test');
sub test {
  my($testname,$targets,@find)=@_;
  $targets or $targets=[];
  # Do it using get all
  my $g_results;
  my $cursor=$autodb->find(@find);
  @$g_results=$cursor->get;
  is(scalar @$g_results,scalar @$targets,"$testname: get: number of objects");
  cmp_deeply($g_results,$targets,"$testname: get: objects");
  # Do it again using get_next
  my $gn_results;
  my $cursor=$autodb->find(@find);
  while(my $result=$cursor->get_next) {
    push(@$gn_results,$result);
  }
  is(scalar @$gn_results,scalar @$targets,"$testname: get_next: number of objects");
  cmp_deeply($gn_results,$targets,"$testname: get_next: objects");
  # make sure get and get_next got the same exact objects
  is_shallow($g_results,$gn_results,"$testname: get & get_next: exact same objects");
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

# create test object -- last state of object from testAutoDB12a.put.t
my $obj=new testAutoDB;
$obj->skey1('changed string1');
$obj->skey2(34);
$obj->skey3(3.4);
$obj->skey4(undef);
$obj->lkey1(['changed string1','changed string2']);
$obj->lkey2([56,78,90]);
$obj->lkey3([5.6,7.8,9.10,11.12]);
$obj->lkey4([]);

# tests start here
# do one find/get operations -- after this, objects all in memory
test('Collection',[$obj], -collection=>'Collection');

