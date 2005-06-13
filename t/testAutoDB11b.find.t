use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Serialize;
use Class::AutoDB::Object;
use testAutoDB11;
use testAutoDB11a;

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

my $obj=new testAutoDB
  (skey1=>'string1',skey2=>12,skey3=>1.2,
   lkey1=>['string1','string2'],
   lkey2=>[12,34,56],
   lkey3=>[1.2],
  );
$obj->skey4($obj);
$obj->lkey4([$obj]);

# tests start here
# do one find/get operations -- after this, objects all in memory
test('Collection',[$obj], -collection=>'Collection');

