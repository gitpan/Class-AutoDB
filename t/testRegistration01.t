use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::Registration;

# Test Class::AutoDB::Registration
# Simple black box testing of the interface

sub do_test {
  my($testname,$class,$collection,$keys,$transients,$auto_gets)=@_;
  my @args;
  push(@args,(-class=>$class)) if $class;
  push(@args,(-collection=>$collection)) if $collection;
  push(@args,(-keys=>$keys)) if $keys;
  push(@args,(-transients=>$transients)) if $transients;
  push(@args,(-auto_gets=>$auto_gets)) if $auto_gets;

  my $registration=new Class::AutoDB::Registration(@args);
  ok($registration,"$testname: new");
  do_test_really($testname,$registration,$class,$collection,$keys,$transients,$auto_gets);
}
sub do_test_really {
  my($testname,$registration,$class,$collection,$keys,$transients,$auto_gets)=@_;
  my $collections=ref $collection? $collection: defined $collection? [$collection]: [];
  
  # test accessors
  is($registration->class,$class,"$testname: class");
  
  my @t_collection=$registration->collection;
  my $t_collection=$registration->collection;
  my @t_collections=$registration->collections;
  my $t_collections=$registration->collections;
  is_deeply(\@t_collection,$collections,"$testname: collection as ARRAY");
  is($t_collection,$collections->[0],"$testname: collection as ARRAY ref");
  is_deeply(\@t_collections,$collections,"$testname: collections as ARRAY");
  is_deeply($t_collections,$collections,"$testname: collections as ARRAY ref");
  
  my %t_keys=$registration->keys;
  my $t_keys=$registration->keys;
  is(norm_keys(\%t_keys),norm_keys($keys),"$testname: keys as HASH");
  is(norm_keys($t_keys),norm_keys($keys),"$testname: keys as HASH ref");

  my @t_transients=$registration->transients;
  my $t_transients=$registration->transients;
  is_deeply(\@t_transients,$transients||[],"$testname: transients as ARRAY");
  is_deeply($t_transients,$transients||[],"$testname: transients as ARRAY ref");

  my @t_auto_gets=$registration->auto_gets;
  my $t_auto_gets=$registration->auto_gets;
  is_deeply(\@t_auto_gets,$auto_gets||[],"$testname: auto_gets as ARRAY");
  is_deeply($t_auto_gets,$auto_gets||[],"$testname: auto_gets as ARRAY ref");

  # try it again with -collections version of arg
  if ($collection) {
    my @args;
    push(@args,(-class=>$class)) if $class;
    push(@args,(-collections=>$collections));
    push(@args,(-keys=>$keys)) if $keys;
    push(@args,(-transients=>$transients)) if $transients;
    push(@args,(-auto_gets=>$auto_gets)) if $auto_gets;
    my $registration=new Class::AutoDB::Registration(@args);
  
    my @t_collection=$registration->collection;
    my $t_collection=$registration->collection;
    my @t_collections=$registration->collections;
    my $t_collections=$registration->collections;
    is_deeply(\@t_collection,$collections,"$testname: collection as ARRAY (-collections form)");
    is($t_collection,$collections->[0],"$testname: collection as ARRAY ref (-collections form)");
    is_deeply(\@t_collections,$collections,"$testname: collections as ARRAY (-collections form)");
    is_deeply($t_collections,$collections,"$testname: collections as ARRAY ref (-collections form)");
  }
}
sub norm_keys {
  my($keys)=@_;
  return undef unless $keys;
  my @norm;
  if ('HASH' eq ref $keys) {	   # structure returned by 'keys' method
    while(my($key,$type)=each %$keys) {
      push(@norm,"$key $type");
    }
  } elsif ('ARRAY' eq ref $keys) { # list of attributes
    @norm=map {"$_ string"} @$keys;
  } else {			   # string of attribute, type pairs
    $keys=~s/\s+/ /g;
    @norm=split(/\s*,\s*/,$keys);
  }
  join(',',sort @norm) || undef;
}

my $registration=do_test('empty registration');
my $registration=do_test
  ('registration with class',
   'Class',
   undef,undef,undef,undef);
my $registration=do_test
  ('registration with collection',
   undef,
   'Collection',
   undef,undef,undef);
my $registration=do_test
  ('registration with keys string',
   undef,undef,
   qq(name string, dob integer, grade_avg float, significant_other object, friends list(object)),
   undef,undef);
my $registration=do_test
  ('registration with keys list',
   undef,undef,
   [qw(key1 key2 key3 key4)],
   undef,undef);
my $registration=do_test
  ('registration with transients',
   undef,undef,undef,
   [qw(tra1 tra2 tra3 tra4)],
   undef);
my $registration=do_test
  ('registration with auto_gets',
   undef,undef,undef,undef,
   [qw(get1 get2 get3 get4)],
  );
my $registration=do_test
  ('registration with all attributes',
   'Class',
   'Collection',
   qq(name string, dob integer, grade_avg float, significant_other object, friends list(object)),
   [qw(tra1 tra2 tra3 tra4)],
   [qw(get1 get2 get3 get4)],
  );

# Test boundary cases for collections
my $registration=do_test
  ('registration with 0 collections',undef,[],undef,undef,undef);
my $registration=do_test
  ('registration with 1 collection',undef,[qw(Coll1)],undef,undef,undef);
my $registration=do_test
  ('registration with 2 collections',undef,[qw(Coll1 Coll2)],undef,undef,undef);
my $registration=do_test
  ('registration with 3 collections',undef,[qw(Coll1 Coll2 Coll3)],undef,undef,undef);
my $registration=do_test
  ('registration with 4 collections',undef,[qw(Coll1 Coll2 Coll3 Coll4)],undef,undef,undef);

# Test boundary cases for keys
my $registration=do_test
  ('registration with 0 keys - string',undef,undef,'',undef,undef);
my $registration=do_test
  ('registration with 0 keys - list',undef,undef,[],undef,undef);
my $registration=do_test
  ('registration with 1 key - string',undef,undef,'key1 integer',undef,undef);
my $registration=do_test
  ('registration with 1 key - list',undef,undef,[qw(key1)],undef,undef);
my $registration=do_test
  ('registration with 2 keys - string',undef,undef,'key1 integer, key2 integer',undef,undef);
my $registration=do_test
  ('registration with 2 keys - list',undef,undef,[qw(key1 key2)],undef,undef);
my $registration=do_test
  ('registration with 3 keys - string',undef,undef,
   'key1 integer, key2 integer, key3 integer',
   undef,undef);
my $registration=do_test
  ('registration with 3 keys - list',undef,undef,[qw(key1 key2 key3)],undef,undef);
my $registration=do_test
  ('registration with 4 keys - string',undef,undef,
   'key1 integer, key2 integer, key3 integer, key4 integer',
   undef,undef);
my $registration=do_test
  ('registration with 4 keys - list',undef,undef,[qw(key1 key2 key3 key4)],undef,undef);

# Test mutators
# Start with empty object
my $registration=new Class::AutoDB::Registration;

# Set each attribute
$registration->class('Class');
$registration->collection('Collection');
$registration->keys(qq(name string, dob integer, grade_avg float, significant_other object,
		       friends list(object)));
$registration->transients([qw(tra1 tra2 tra3 tra4)]);
$registration->auto_gets([qw(get1 get2 get3 get4)]);
do_test_really
  ('registration after all attributes set',$registration,
   'Class',
   'Collection',
   qq(name string, dob integer, grade_avg float, significant_other object, friends list(object)),
   [qw(tra1 tra2 tra3 tra4)],
   [qw(get1 get2 get3 get4)],
  );

# Unset each attribute
$registration->class(undef);
$registration->collection(undef);
$registration->keys(undef);
$registration->transients(undef);
$registration->auto_gets(undef);
do_test_really
  ('registration after all attributes unset',$registration,undef,undef,undef,undef,undef);

# Set keys using list form
$registration->keys([qw(key1 key2 key3 key4)]);
do_test_really
  ('registration after key set using list form',$registration,undef,undef,
   [qw(key1 key2 key3 key4)],
    undef,undef);


