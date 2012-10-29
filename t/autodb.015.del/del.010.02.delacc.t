########################################
# get, delete, then access objects stored by del.010.00.put
########################################
use t::lib;
use strict;
use Carp;
use Test::More;
use autodbTestObject;

use Class::AutoDB;
use delUtil; use Person; use Student; use Place; use School; use Thing;

my $first_case=@ARGV? shift: 0;
my $autodb=new Class::AutoDB(database=>'test'); # open database

# get the objects
my @persons=$autodb->get(collection=>'Person');
my @places=$autodb->get(collection=>'Place');
my @things=gentle_uniq map {@{$_->hobbies}} @persons; # Things have no collection. get via hobbies
my @objects=(@persons,@places,@things);
my @classes=map {UNIVERSAL::isa($_,'Class::AutoDB::Oid')? $_->{_CLASS}: ref $_} @objects;
report_fail
  (scalar(@objects),'objects exist - probably have to rerun put script',__FILE__,__LINE__);

# diag "\$first_case=$first_case";
confess "first_case=$first_case too big. max is ".scalar @objects if $first_case>@objects;
isa_ok($autodb,'Class::AutoDB','class is Class::AutoDB - sanity check');

# create test object
# %test_args, exported by delUtil, sets class2colls, coll2keys, label
my $test=new autodbTestObject(%test_args);

# delete the objects
$test->test_del
    (labelprefix=>"del objects:",objects=>\@objects);

# now do the real tests. 
# application & UNIVERSAL methods should confess. 'oid' should work. 'put' is nop
for (my $i=0; $i<@objects; $i++) {
  my $case=($first_case+$i)%@objects; 
  my $obj=$objects[$case];
  my $oid=obj2oid($obj);
  my $class=$classes[$case];
  my $labelprefix="case $case $class";
  # test application method
  my $ok=1;
  my $actual=eval {$obj->id;};
  if ($@) {
    $ok&&=report_fail
      (scalar $@=~/Trying to access deleted object of class \S+ via method id \(oid=$oid\)/,
       "application method (id) confessed but with wrong message: $@",__FILE__,__LINE__);
  } else {
    $ok&&=report_fail
      (0,"application method was supposed to confess but did not",__FILE__,__LINE__);
  }
  $ok&&=ok_objcache
    ($obj,$oid,'OidDeleted',$class,
     'application method (id) did not fetch object',__FILE__,__LINE__,'no_report_pass');
  report_pass($ok,"$labelprefix: application method");
  # NG 12-10-28: test UNIVERSAL methods: isa, can, DOES, VERSION
  my $ok=1;
  for my $method (qw(isa can DOES VERSION)) {
    my $actual=eval {$obj->$method;};
    if ($@) {
      $ok&&=report_fail
	(scalar $@=~/Trying to access deleted object of class \S+ via method $method \(oid=$oid\)/,
	 "UNIVERSAL method ($method) confessed but with wrong message: $@",__FILE__,__LINE__);
    } else {
      $ok&&=report_fail
	(0,"UNIVERSAL method was supposed to confess but did not",__FILE__,__LINE__);
    }
    $ok&&=ok_objcache
      ($obj,$oid,'OidDeleted',$class,
       'UNIVERSAL method ($method) did not fetch object',__FILE__,__LINE__,'no_report_pass');
  }
  report_pass($ok,"$labelprefix: application method");

  # test 'oid' method
  my $ok=1;
  my $actual=eval{$obj->oid;};
  $ok&&=report_fail($@ eq '',$@,__FILE__,__LINE__);
  $ok&&=report_fail
    ($actual==$oid,
     "oid method returned correct value. Expected $oid. Got $actual",__FILE__,__LINE__);
  $ok&&=ok_objcache
    ($obj,$oid,'OidDeleted',$class,
     'oid method did not fetch object',__FILE__,__LINE__,'no_report_pass');
  report_pass($ok,"$labelprefix: oid method");
  # test 'put' method
  my $ok=1;
  my $actual=eval{$obj->put;};            # should be nop.
  $ok&&=report_fail($@ eq '',$@,__FILE__,__LINE__);
  $ok&&=ok_objcache
    ($obj,$oid,'OidDeleted',$class,
     'put method did not fetch object',__FILE__,__LINE__,'no_report_pass');
  report_pass($ok,"$labelprefix: put method");
}

done_testing();
