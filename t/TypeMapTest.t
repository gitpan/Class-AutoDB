use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::TypeMap;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use Error qw(:try);
use Data::Dumper; # only for testing

my $exception; # $exception string

# prep collection
my $coll1 = new Class::AutoDB::Collection(-name=>'Person');
my $reg1 = new Class::AutoDB::Registration(
                                            -class=>'Class::Person',
                                            -collection=>'Person',
                                            -keys=>qq(name string, 
                                                      id int, 
                                                      residence object, 
                                                      friends list(object),
                                                      nick_names list(string),
                                                      ));
$coll1->register($reg1);

my $coll2 = new Class::AutoDB::Collection(-name=>'Flower');
my $reg2 = new Class::AutoDB::Registration(
                                            -class=>'Class::Plant',
                                            -collection=>'Flower',
                                            -keys=>qq(name string, petals int, color string));
$coll2->register($reg2);

my $tm_no_init = new Class::AutoDB::TypeMap;
is(ref $tm_no_init,'Class::AutoDB::TypeMap');
is($tm_no_init->count,0);

my $tm_init = new Class::AutoDB::TypeMap(-collections=>[$coll1, $coll2]);
is(ref $tm_init,'Class::AutoDB::TypeMap');
is($tm_init->count,2);

# load a collection into $tm_no_init and recheck count
$tm_no_init->load($coll1);
is($tm_no_init->count,1);
$tm_no_init->load($coll2);
is($tm_no_init->count,2);

# keys_for : get the keys for a specified collection
my %person_keys = $tm_init->keys_for('Person');
is(scalar keys %person_keys, 5);
is(scalar $tm_init->type_of('friends','Person'),'list(object)');

# check validity of values (see which values are allowed for a given type)
# then clean them and check again
my $string = 'blah';
my $scalarref = \1;
my $aryref = ['one', 'two', 'three'];
my $hashref = {one=>1, two=>2, three=>3};
my $coderef = sub {return "hello"};

is($tm_init->is_valid('string',$string), 1);
isnt($tm_init->is_valid('string',\$string), 1, 'string type check for scalar ref');
my $clean_sr = $tm_init->clean('string',$scalarref);
is($tm_init->is_valid('string',$clean_sr), 1, 'scalar ref cleaned');
isnt($tm_init->is_valid('string',$aryref), 1, 'string type check for array ref');
my $clean_ar = $tm_init->clean('string',$aryref);
is($tm_init->is_valid('string',$clean_ar), 1, 'array ref cleaned');
isnt($tm_init->is_valid('string',$hashref), 1, 'string type check for hash ref');
my $clean_hr = $tm_init->clean('string',$hashref);
is($tm_init->is_valid('string',$clean_hr), 1, 'hash ref cleaned');
isnt($tm_init->is_valid('string',$coderef), 1, 'string type check for code ref');
my $clean_cr = $tm_init->clean('string',$coderef);
is($clean_cr, undef,'code ref cleaned');

my @nums = qw/1 0 00000001 1a 2147483647  2147483648 2147483649 4294967295 4294967296/;
# check signed ints
is($tm_init->is_valid('int',$nums[0]), 1);
is($tm_init->is_valid('int',$nums[1]), 1);
is($tm_init->is_valid('int',$nums[2]), 1);
isnt($tm_init->is_valid('int',$nums[3]), 1, 'alphas are rejected for signed int checks');
is($tm_init->is_valid('int',$nums[4]), 1, 'signed int upper bounderies check out');
is($tm_init->is_valid('int',-$nums[5]), 1, 'signed int lower bounderies check out');
isnt($tm_init->is_valid('int',$nums[5]), 1, 'signed ints > 2147483647 are rejected for int checks');
isnt($tm_init->is_valid('int',-$nums[6]), 1, 'signed ints < -2147483648 are rejected for int checks');
# check unsigned ints
is($tm_init->is_valid('unsigned',$nums[0]), 1);
isnt($tm_init->is_valid('unsigned',$nums[3]), 1, 'alphas are rejected for unsigned int checks');
is($tm_init->is_valid('unsigned',$nums[7]), 1, 'unsigned int upper bounderies check out');
is($tm_init->is_valid('unsigned',$nums[1]), 1, 'unsigned int lower bounderies check out');
isnt($tm_init->is_valid('unsigned',$nums[8]), 1, 'unsigned ints > 4294967295 are rejected for int checks');
isnt($tm_init->is_valid('unsigned',-$nums[0]), 1, 'unsigned ints < 0 are rejected for int checks');
# check floats
is($tm_init->is_valid('float',$nums[0]), 1);
is($tm_init->is_valid('float',$nums[1]), 1);
isnt($tm_init->is_valid('float',$nums[3]), 1, 'alphas are rejected for double checks');
# check objects - only inside objects are accepted (can't generate search keys for others)
use Person;
my $inside = new Person(-name=>'white spy',-sex=>'male');
is($tm_init->is_inside($inside),1);
is($tm_init->is_outside($inside),0);
use TestAutoDBOutside_1;
my $outside = new TestAutoDBOutside_1;
is($tm_init->is_inside($outside),0);
is($tm_init->is_outside($outside),1);
# test scalar and list refs for insidedness
is($tm_init->is_inside($aryref),0);
is($tm_init->is_outside($aryref),0);

is($tm_init->is_inside($hashref),0);
is($tm_init->is_outside($hashref),0);

is($tm_init->is_inside($scalarref),0);
is($tm_init->is_outside($scalarref),0);
is($tm_init->is_inside('blah'),0);
is($tm_init->is_outside('blah'),0);

exit;

isnt($tm_init->is_valid('object',$scalarref), 1, 'checking scalar ref as object type');
isnt($tm_init->is_valid('object',$aryref), 1, 'checking array ref as object type');
isnt($tm_init->is_valid('object',$hashref), 1, 'checking hash ref as object type');
is($tm_init->is_valid('object',$inside), 1, 'checking inside object type');
isnt($tm_init->is_valid('object',$outside), 1, 'checking outside object type');
## list var templates
my $list_s = [$string];
my $list_ss = [$string, $string];
my $list_i = [$inside];
my $list_ii = [$inside, $inside];
my $list_io = [$inside, $outside];
my $list_o = [$outside];
my $list_oo = [$outside, $outside];
my $list_si = [$string, $inside];
my $list_so = [$string, $outside];
my $list_soi = [$string, $outside, $inside];

## check lists of string type
try {
  $tm_init->is_valid('list(string)',undef);
  return;
}
catch Error with {
  $exception = shift;   # Get hold of the exception object
};
ok($exception =~ /EXCEPTION/,'testing list of string type');
undef $exception;

is($tm_init->is_valid('list(string)',$list_s), 1);
is(scalar @{$tm_init->clean('list(string)',$list_s)}, 1);

is($tm_init->is_valid('list(string)',$list_ss), 1);
is(scalar @{$tm_init->clean('list(string)',$list_ss)}, 2);

isnt($tm_init->is_valid('list(string)',$list_i), 1);
is($tm_init->clean('list(string)',$list_i), undef);

isnt($tm_init->is_valid('list(string)',$list_si), 1);
my $clean_list_si = $tm_init->clean('list(string)',$list_si);
is(scalar @$clean_list_si, 1);
is($tm_init->is_valid('list(string)',$clean_list_si), 1);

isnt($tm_init->is_valid('list(string)',$list_o), 1);
is($tm_init->clean('list(string)',$list_o), undef);

isnt($tm_init->is_valid('list(string)',$list_soi), 1);
my $clean_list_soi = $tm_init->clean('list(string)',$list_soi);
is(scalar @$clean_list_soi, 1);
is($tm_init->is_valid('list(string)',$clean_list_soi), 1);

## check lists of object type - only inside objects are allowed for storage
try {
  $tm_init->is_valid('list(object)',undef);
  return;
}
catch Error with {
  $exception = shift;   # Get hold of the exception object
};
ok($exception =~ /EXCEPTION/,'testing list of object type');
undef $exception;
isnt($tm_init->is_valid('list(object)',$list_s), 1);
is($tm_init->clean('list(object)',$list_s), undef);

isnt($tm_init->is_valid('list(object)',$list_ss), 1);
is($tm_init->clean('list(object)',$list_ss), undef);

is($tm_init->is_valid('list(object)',$list_i), 1);
is(scalar @{$tm_init->clean('list(object)',$list_i)}, 1);

isnt($tm_init->is_valid('list(object)',$list_si), 1);
my $cleaned_list_si = $tm_init->clean('list(object)',$list_si);
is(scalar @{$tm_init->clean('list(object)',$list_si)}, 1);
is($tm_init->is_valid('list(object)',$cleaned_list_si), 1);

is($tm_init->is_valid('list(object)',$list_ii), 1);
is(scalar @{$tm_init->clean('list(object)',$list_ii)}, 2);

isnt($tm_init->is_valid('list(object)',$list_o), 1);
is($tm_init->clean('list(object)',$list_o), undef);

isnt($tm_init->is_valid('list(object)',$list_so), 1);
is($tm_init->clean('list(object)',$list_o), undef);

## check lists of mixed type ('list(mixed)') - both strings and inside objects are ok
try {
  $tm_init->is_valid('list(mixed)',undef);
  return;
}
catch Error with {
  $exception = shift;   # Get hold of the exception object
};
ok($exception =~ /EXCEPTION/,'testing list of mixed type');
undef $exception;
is($tm_init->is_valid('list(mixed)',$list_s), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_s)}, 1);

is($tm_init->is_valid('list(mixed)',$list_i), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_i)}, 1);

is($tm_init->is_valid('list(mixed)',$list_ss), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_ss)}, 2);

is($tm_init->is_valid('list(mixed)',$list_si), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_si)}, 2);

isnt($tm_init->is_valid('list(mixed)',[$inside, $scalarref]), 1);
is(scalar @{$tm_init->clean('list(mixed)',[$inside, $scalarref])}, 2);

isnt($tm_init->is_valid('list(mixed)',[$inside, $aryref]), 1);
is(scalar @{$tm_init->clean('list(mixed)',[$inside, $aryref])}, 2);

is($tm_init->is_valid('list(mixed)',$list_ii), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_ii)}, 2);

isnt($tm_init->is_valid('list(mixed)',$list_o), 1);
is($tm_init->clean('list(mixed)',$list_o), undef);

isnt($tm_init->is_valid('list(mixed)',$list_so), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_so)}, 1);

isnt($tm_init->is_valid('list(mixed)',$list_io), 1);
is(scalar @{$tm_init->clean('list(mixed)',$list_io)}, 1);

1;