use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoDB;
use Class::AutoDB::Object;
use testAutoDB13;
use testAutoDB13a;

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

# create test objects -- last state of objects from testAutoDB13a.put.t
my $top_obj=new testAutoDBTop(-top_key=>'top object');
my $left_obj=new testAutoDBLeft(-top_key=>'top of left object',-left_key=>'left object');
my $right_obj=new testAutoDBRight(top_key=>'top of right object',-right_key=>'right object');
my $bottom_obj=new testAutoDBBottom
  (-top_key=>'top of bottom object',
   -left_key=>'left of bottom object',
   -right_key=>'right of bottom object',
   -bottom_key=>'bottom object');

# tests start here
# do one find/get operation per collection -- after this, objects all in memory
test('bottom',[$bottom_obj],-collection=>'CollectionBottom');
test('right',[$right_obj,$bottom_obj],-collection=>'CollectionRight');
test('left',[$left_obj,$bottom_obj],-collection=>'CollectionLeft');
test('top',[$top_obj,$left_obj,$right_obj,$bottom_obj],-collection=>'CollectionTop');

