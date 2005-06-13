use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::Registration;
use Class::AutoDB::CollectionDiff;
use Class::AutoDB::Collection;


# Test Class::AutoDB::Collection
# Test methods that use CollectionDiffs.  Logically, should be run after testCollectionDiff01.t

sub test {
  my($testname,$baseline,$other_register,$keys)=@_;
  my $other=new Class::AutoDB::Collection(-name=>'Other',-register=>$other_register);
  my $diff=new Class::AutoDB::CollectionDiff(-baseline=>$baseline,-other=>$other);
  $baseline->merge($diff);
  test_really($testname,$baseline,$baseline->name,$keys);
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
# Start with no registrations and add in new ones
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 0 keys',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration'),
   {},
);
my $collection=test
  ('collection merge 1 scalar key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $collection=test
  ('collection merge 2 scalar keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );
my $collection=test
  ('collection merge 3 scalar keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
my $collection=test
  ('collection merge 4 scalar keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );
my $collection=test
  ('collection merge 1 list key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)'},
  );
my $collection=test
  ('collection merge 2 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $collection=test
  ('collection merge 3 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $collection=test
  ('collection merge 4 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Start over with no registrations and add in new ones
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 1 scalar and 1 list key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string,
	     lkey1 list(string))),
   {skey1=>'string',
    lkey1=>'list(string)'},
  );
my $collection=test
  ('collection merge 2 scalar and 2 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string,
	     lkey1 list(string), lkey2 list(string))),
  {skey1=>'string',skey2=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $collection=test
  ('collection merge 3 scalar and 3 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $collection=test
  ('collection merge 4 scalar and 4 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Do it again, starting from scratch each time
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 0 keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration'),
   {},
);
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 1 scalar key (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 2 scalar keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 3 scalar keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 4 scalar keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 1 list key (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string))),
   {lkey1=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 2 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 3 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 4 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 1 scalar and 1 list key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string,
	     lkey1 list(string))),
   {skey1=>'string',
    lkey1=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 2 scalar and 2 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string,
	     lkey1 list(string), lkey2 list(string))),
  {skey1=>'string',skey2=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 3 scalar and 3 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=test
  ('collection merge 4 scalar and 4 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Test some special cases
my $baseline=new Class::AutoDB::Collection
  (-name=>'baseline',
   -register=>new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)));
my $collection=test
  ('collection merge identical scalar key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $collection=test
  ('collection merge disjoint scalar key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );

my $baseline=new Class::AutoDB::Collection
  (-name=>'baseline',
   -register=>new Class::AutoDB::Registration(-class=>'Registration',
					      -keys=>q(lkey1 list(string))));
my $collection=test
  ('collection merge identical list key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(lkey1 list(string))),
   {lkey1=>'list(string)'},
  );
my $collection=test
  ('collection merge disjoint list key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(lkey2 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)'},
  );
