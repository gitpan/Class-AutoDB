########################################
# create and put some objects for testing deferred thawing of deleted objects
# this set (10, 11) checks that stringification causes thaw. this includes
#   double quotes, bool, and string comparison ops (cmp, eq, etc)
# scheme is to create a root object pointing to 'matrix' of deleted test objects: 
#   1 test object each for double quotes and bool, 2 for each binary op.
#   thaw them one-by-one. at end, make sure all are OidDeleteds.
########################################
use t::lib;
use strict;
use Carp;
use Test::More;
use autodbTestObject;

use Class::AutoDB;
use delUtil; use Mechanics;

my($del_type)=@ARGV;
my @object_names=qw(quotes bool cmp cmp lt lt le le eq eq ge ge gt gt ne ne);
my $num_objects=scalar @object_names;
defined $del_type or $del_type='put';

# create AutoDB database & SDBM files
my $autodb=new Class::AutoDB(database=>testdb,create=>1); 
isa_ok($autodb,'Class::AutoDB','class is Class::AutoDB - sanity check');
tie_oid('create');

# make the objects
my $root=new Mechanics(name=>'root',id=>id_next(),list_count=>0);
my @matrix=
  map {new Mechanics (name=>$_,id=>id_next(),list_count=>0)} (0..$num_objects-1);
# connect 'em up
$root->object_list(\@matrix);
map {$_->object_list(\@matrix)} @matrix;

# put all, then del matrix
$autodb->put_objects;
# %test_args, exported by delUtil, sets class2colls, coll2keys, label
my $test=new autodbTestObject(%test_args,del_type=>$del_type);
$test->test_del(labelprefix=>"$del_type matrix",del_type=>$del_type,objects=>\@matrix,
		correct_diffs=>{Mechanics=>1,Mechanics_object_list=>$num_objects});
done_testing();
