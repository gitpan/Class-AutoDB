use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::Registration;
use Class::AutoDB::Collection;


# Test Class::AutoDB::Collection
# Simple black box testing of the interface

sub test {
  my($testname,$name,$register,$keys)=@_;
  my @args;
  push(@args,(-name=>$name)) if $name;
  push(@args,(-register=>$register)) if $register;
  my $collection=new Class::AutoDB::Collection(@args);
  isa_ok($collection,'Class::AutoDB::Collection',"$testname: collection");
  test_really($testname,$collection,$name,$keys);
}

sub test_really {
  my($testname,$collection,$name,$keys)=@_;
  is($collection->name,$name,"$testname: name");
  my %t_keys=$collection->keys;
  my $t_keys=$collection->keys;
  is_deeply(\%t_keys,$keys||{},"$testname: keys as HASH");
  is_deeply($t_keys,$keys||{},"$testname: keys as HASH ref");
  my @t_tables=$collection->tables;
  my $t_tables=$collection->tables;
  ok_tables($name,\@t_tables,$keys,"$testname: tables as ARRAY");
  ok_tables($name,$t_tables,$keys,"$testname: tables as ARRAY ref");
  
  # test schema methods -- Table tests do the heavy lifting, just test counts here
  if ($name) { 
    my $count=scalar @t_tables;
    my @t_create=$collection->create;
    my $t_create=$collection->create;
    is(scalar @t_create,2*$count,"$testname: create as ARRAY");
    is(scalar @$t_create,2*$count,"$testname: create as ARRAY ref");
    
    my @t_drop=$collection->drop;
    my $t_drop=$collection->drop;
    is(scalar @t_drop,$count,"$testname: drop as ARRAY");
    is(scalar @$t_drop,$count,"$testname: drop as ARRAY ref");
  }
  $collection;
}
sub norm_tables {
  my $name=shift;
  return undef unless $_[0];
  my @norm;
  if ('HASH' eq ref $_[0]) {	   # infer tables from $keys
    my($keys)=@_;
    # base table for scalar keys
    my $base_table=new Class::AutoDB::Table(-name=>$name);
    my $base_keys={};
    push(@norm,$base_table);
    while(my($key,$type)=each %$keys) {
      if (my($list_type)=$type=~/list\s*\((.*)\s*\)/i) {
	# link table for list key
	my $list_table=new Class::AutoDB::Table(-name=>$name."_$key",-keys=>{$key=>$list_type});
	push(@norm,$list_table);
      } else {
	$base_keys->{$key}=$type;
      }
    }
    $base_table->keys($base_keys);
  } elsif ('ARRAY' eq ref $_[0]) { # ARRAY of tables from Collection object
    @norm=@{$_[0]};
  } else {
    die "Unkown argument type for norm_table"
  }
  @norm=sort {$a->name cmp $b->name} @norm;
  \@norm;
}
sub ok_tables {
  my($name,$t_tables,$keys,$label)=@_;
  is_deeply(norm_tables($name,$t_tables),norm_tables($name,$keys||{}),$label);
}

# Tests start here
#goto skip;

my $collection=test('empty collection');
my $collection=test
  ('collection with name',
   'Person',
   undef,
   undef,
  );
my $collection=test
  ('collection with registration - scalar keys only',
   undef,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(name string, dob integer, significant_other object)),
   {name=>'string',dob=>'integer',significant_other=>'object'},
  );
my $collection=test
  ('collection with registration - scalar keys and 1 list key',
   undef,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(name string, dob integer, significant_other object, friends list(object))),
   {name=>'string',dob=>'integer',significant_other=>'object',friends=>'list(object)'},
  );
my $collection=test
  ('collection with name and registration - scalar keys only',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(name string, dob integer, significant_other object)),
   {name=>'string',dob=>'integer',significant_other=>'object'},
  );
my $collection=test
  ('collection with name and registration - scalar keys and 1 list key',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(name string, dob integer, significant_other object, friends list(object))),
   {name=>'string',dob=>'integer',significant_other=>'object',friends=>'list(object)'},
  );
my $collection=test
  ('collection with name and registration - 1 key of each type (scalar and list)',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 integer, skey3 float, skey4 object,
	     lkey1 list(string), lkey2 list(integer), lkey3 list(float), lkey4 list(object))),
   {skey1=>'string',skey2=>'integer',skey3=>'float',skey4=>'object',
    lkey1=>'list(string)',lkey2=>'list(integer)',lkey3=>'list(float)',lkey4=>'list(object)'},
  );

my $collection=test
  ('collection with name and 2 registrations - identical',
   'Person',
   [new Class::AutoDB::Registration
    (-class=>'Registration',
     -keys=>q(skey1 string, skey2 integer, skey3 float, skey4 object,
	      lkey1 list(string), lkey2 list(integer), lkey3 list(float), lkey4 list(object))),
    new Class::AutoDB::Registration
    (-class=>'Registration',
     -keys=>q(skey1 string, skey2 integer, skey3 float, skey4 object,
	      lkey1 list(string), lkey2 list(integer), lkey3 list(float), lkey4 list(object))),
   ],
   {skey1=>'string',skey2=>'integer',skey3=>'float',skey4=>'object',
    lkey1=>'list(string)',lkey2=>'list(integer)',lkey3=>'list(float)',lkey4=>'list(object)'},
  );
my $collection=test
  ('collection with name and 2 registrations - disjoint',
   'Person',
   [new Class::AutoDB::Registration
    (-class=>'Registration',
     -keys=>q(skey1 string, skey2 integer,
	      lkey1 list(string), lkey2 list(integer))),
    new Class::AutoDB::Registration
    (-class=>'Registration',
     -keys=>q(skey3 float, skey4 object,
	      lkey3 list(float), lkey4 list(object))),
   ],
   {skey1=>'string',skey2=>'integer',skey3=>'float',skey4=>'object',
    lkey1=>'list(string)',lkey2=>'list(integer)',lkey3=>'list(float)',lkey4=>'list(object)'},
  );
my $collection=test
  ('collection with name and 2 registrations - overlapping consistent',
   'Person',
   [new Class::AutoDB::Registration
    (-class=>'Registration',
     -keys=>q(skey1 string, skey2 integer, skey3 float,
	      lkey1 list(string), lkey2 list(integer), lkey3 list(float))),
    new Class::AutoDB::Registration
    (-class=>'Registration',
     -keys=>q(skey2 integer, skey3 float, skey4 object,
	      lkey2 list(integer), lkey3 list(float), lkey4 list(object))),
   ],
   {skey1=>'string',skey2=>'integer',skey3=>'float',skey4=>'object',
    lkey1=>'list(string)',lkey2=>'list(integer)',lkey3=>'list(float)',lkey4=>'list(object)'},
  );


  eval {
    my $collection=new Class::AutoDB::Collection
      (-name=>'Person',
       -register=>
       [new Class::AutoDB::Registration
	(-class=>'Registration',
	 -keys=>q(skey1 string, skey2 integer, skey3 string,
		  lkey1 list(string), lkey2 list(integer), lkey3 list(string))),
	new Class::AutoDB::Registration
	(-class=>'Registration',
	 -keys=>q(skey2 string, skey3 float, skey4 object,
		  lkey2 list(string), lkey3 list(float), lkey4 list(object))),
       ]);
  };
  ok($@=~ /Inconsistent registrations/i,'collection with name and 2 inconsistent registrations');

# Test boundary cases for keys
my $collection=test
  ('collection with name and 0 keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration'),
   {},
  );
my $collection=test
  ('collection with name and 1 scalar key',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $collection=test
  ('collection with name and 2 scalar keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );
my $collection=test
  ('collection with name and 3 scalar keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
my $collection=test
  ('collection with name and 4 scalar keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );
my $collection=test
  ('collection with name and 1 list key',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string))),
   {lkey1=>'list(string)'},
  );
my $collection=test
  ('collection with name and 2 list keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $collection=test
  ('collection with name and 3 list keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $collection=test
  ('collection with name and 4 list keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

my $collection=test
  ('collection with name and 1 scalar and 1 list key',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string,
	     lkey1 list(string))),
   {skey1=>'string',
    lkey1=>'list(string)'},
  );
my $collection=test
  ('collection with name and 2 scalar and 2 list keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string,
	     lkey1 list(string), lkey2 list(string))),
  {skey1=>'string',skey2=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $collection=test
  ('collection with name and 3 scalar and 3 list keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $collection=test
  ('collection with name and 4 scalar and 4 list keys',
   'Person',
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Test boundary cases for registrations
my $collection=test
  ('collection with name and 0 registrations',
   'Person',
   [],
   {},
  );
my $collection=test
  ('collection with name and 1 registration',
   'Person',
   [new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
   ],
   {skey1=>'string'},
  );
my $collection=test
  ('collection with name and 2 registrations',
   'Person',
   [new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
   ],
   {skey1=>'string',skey2=>'string'},
  );
my $collection=test
  ('collection with name and 3 registrations',
   'Person',
   [new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey3 string)),
   ],
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
my $collection=test
  ('collection with name and 4 registrations',
   'Person',
   [new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey3 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey4 string)),
   ],
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );

# Test mutators and register
# Start with empty object
my $collection=new Class::AutoDB::Collection;
$collection->name('Person');
test_really
  ('collection after name set',
   $collection,'Person',
   {},
  );
$collection->register([]);
test_really
  ('collection after register - 0 registrations',
   $collection,'Person',
   {},
  );
$collection->register
  ([new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string))]);
test_really
  ('collection after register - 1 registration',
   $collection,'Person',
   {skey1=>'string'},
  );
$collection->register
  ([new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string))]);
test_really
  ('collection after register - 2 registrations',
   $collection,'Person',
   {skey1=>'string',skey2=>'string'},
  );
$collection->register
  ([new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey3 string))]);
test_really
  ('collection after register - 3 registrations',
   $collection,'Person',
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
$collection->register
  ([new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey3 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey4 string))]);
test_really
  ('collection after register - 4 registrations',
   $collection,'Person',
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );

# Do it again using list form of register
my $collection=new Class::AutoDB::Collection(-name=>'Person');

$collection->register();
test_really
  ('collection after register - 0 registrations (list form)',
   $collection,'Person',
   {},
  );
$collection->register
  (new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)));
test_really
  ('collection after register - 1 registration (list form)',
   $collection,'Person',
   {skey1=>'string'},
  );
$collection->register
  (new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)));
test_really
  ('collection after register - 2 registrations (list form)',
   $collection,'Person',
   {skey1=>'string',skey2=>'string'},
  );
$collection->register
  (new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey3 string)));
test_really
  ('collection after register - 3 registrations (list form)',
   $collection,'Person',
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
$collection->register
  (new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey3 string)),
    new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey4 string)));
test_really
  ('collection after register - 4 registrations (list form)',
   $collection,'Person',
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );

