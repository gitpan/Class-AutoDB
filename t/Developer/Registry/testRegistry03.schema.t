use t::lib;
use strict;
use Test::More;
use Test::Deep;
use Class::AutoClass::Args;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;

# Test Class::AutoDB::Registry
# Test schema operations
# Table tests do the heavy lifting, just test counts here

sub test {
  my($testname,$current,$saved,$collections)=@_;
  my $registry=new Class::AutoDB::Registry;
  
  # create current and saved registry versions for testing
  my $version=new Class::AutoDB::RegistryVersion;
  for my $reg (@$current) {
    my @args=@$reg;
    $version->register(@args);
  }
  $registry->current($version);	# undocumented interface
  my $version=new Class::AutoDB::RegistryVersion;
  for my $reg (@$saved) {
    my @args=@$reg;
    $version->register(@args);
  }
  $registry->saved($version);	# undocumented interface
  
  # get tables from current and saved versions
  my $current_tables=[];
  my $saved_tables=[];
  @$current_tables=map {$_->name} map {$_->tables} $registry->current->collections;
  @$saved_tables=map {$_->name} map {$_->tables} $registry->saved->collections;

  my @t_schema=$registry->schema;
  my $t_schema=$registry->schema;
  my @t_create=$registry->schema('create');
  my $t_create=$registry->schema('create');

  test_create(\@t_schema,$current_tables,$saved_tables,"$testname: schema as ARRAY");
  test_create($t_schema,$current_tables,$saved_tables,"$testname: schema as ARRAY ref");
  test_create(\@t_create,$current_tables,$saved_tables,"$testname: schema('create') as ARRAY");
  test_create($t_create,$current_tables,$saved_tables,"$testname: schema('create') as ARRAY ref");
  
  my @t_drop=$registry->schema('drop');
  my $t_drop=$registry->schema('drop');
  test_drop(\@t_drop,$current_tables,$saved_tables,"$testname: schema('drop') as ARRAY");
  test_drop($t_drop,$current_tables,$saved_tables,"$testname: schema('drop') as ARRAY ref");
  
  # get new and altered tables from registry
  my $new_tables=[];
  my $alter_tables=[];
  $registry->merge;		# remember to merge before diff!!
  my $diff=$registry->diff;
  for my $collection (@{$diff->new_collections}) {
    my @tables=map {$_->name} $collection->tables;
    push(@$new_tables,@tables);
  }
  for my $diff (@{$diff->expanded_diffs}) {
    my $name=$diff->baseline->name; # collection name
    my $new_keys=$diff->new_keys;
    my $has_newcol;
    while(my($key,$type)=each %$new_keys) {
      if ($type=~/list\s*\(.*\)/i) {
	push(@$new_tables,$name."_$key");
      } else {
	$has_newcol=1;
      }
    }
    push(@$alter_tables,$name) if $has_newcol;
  }
  my @t_alter=$registry->schema('alter');
  my $t_alter=$registry->schema('alter');
  test_alter(\@t_alter,$new_tables,$alter_tables,"$testname: schema('alter') as ARRAY");
  test_alter($t_alter,$new_tables,$alter_tables,"$testname: schema('alter') as ARRAY ref");
  
  $registry;
}
# 'create' drops saved tables, then drops & creates current tables
sub test_create {
  my($sqls,$current_tables,$saved_tables,$testname)=@_;
  my $creates=extract_creates($sqls);
  my $drops=extract_drops($sqls);
  my $alters=extract_alters($sqls);
  cmp_bag($creates,$current_tables,"$testname: creates");
  cmp_bag($drops,[@$current_tables,@$saved_tables],"$testname: drops");
  cmp_bag($alters,[],"$testname: alters");
}
# 'drop' drops current and saved tables
sub test_drop {
  my($sqls,$current_tables,$saved_tables,$testname)=@_;
  my $creates=extract_creates($sqls);
  my $drops=extract_drops($sqls);
  my $alters=extract_alters($sqls);
  cmp_bag($creates,[],"$testname: creates");
  cmp_bag($drops,[@$current_tables,@$saved_tables],"$testname: drops");
  cmp_bag($alters,[],"$testname: alters");
}
# 'alter'drops and creates new tables, alters altered tables
sub test_alter {
  my($sqls,$new_tables,$alter_tables,$testname)=@_;
  my $creates=extract_creates($sqls);
  my $drops=extract_drops($sqls);
  my $alters=extract_alters($sqls);
  cmp_bag($creates,$new_tables,"$testname: creates");
  cmp_bag($drops,$new_tables,"$testname: drops");
  cmp_bag($alters,$alter_tables,"$testname: alters");
}
sub extract_creates {
  my($sqls)=@_;
  my @creates;
  for my $sql (@$sqls) {
    my($table)=$sql=~/create table (\w+)/i;
    next unless $table;
    push(@creates,$table);
  }
  wantarray? @creates: \@creates;
}
sub extract_drops {
  my($sqls)=@_;
  my @drops;
  for my $sql (@$sqls) {
    my($table)=$sql=~/drop table if exists (\w+)/i;
    next unless $table;
    push(@drops,$table);
  }
  wantarray? @drops: \@drops;
}
sub extract_alters {
  my($sqls)=@_;
  my @alters;
  for my $sql (@$sqls) {
    my($table)=$sql=~/alter table (\w+)/i;
    next unless $table;
    push(@alters,$table);
  }
  wantarray? @alters: \@alters;
}

sub max {$_[0]<$_[1]? $_[1]: $_[0]}

# Tests start here
#goto skip;

my $registry=test
  ('merge 0 onto 0 registrations',
   [],
   [],
  );

# Single collection tests
my @registers=
  ([-collection=>'Collection',-keys=>q(skey1 string)],
   [-collection=>'Collection',-keys=>q(skey2 string)],
   [-collection=>'Collection',-keys=>q(skey3 string)],
   [-collection=>'Collection',-keys=>q(skey4 string)],
   [-collection=>'Collection',-keys=>q(lkey1 list(string))],
   [-collection=>'Collection',-keys=>q(lkey2 list(string))],
   [-collection=>'Collection',-keys=>q(lkey3 list(string))],
   [-collection=>'Collection',-keys=>q(lkey4 list(string))],  );
my @collections=
  ([-collection=>'Collection',-keys=>q(skey1 string)],
   [-collection=>'Collection',-keys=>q(skey1 string, skey2 string)],
   [-collection=>'Collection',-keys=>q(skey1 string, skey2 string, skey3 string)],
   [-collection=>'Collection',-keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)],
   [-collection=>'Collection',-keys=>
    q(skey1 string, skey2 string, skey3 string, skey4 string,
      lkey1 list(string))],
   [-collection=>'Collection',-keys=>
    q(skey1 string, skey2 string, skey3 string, skey4 string,
      lkey1 list(string), lkey2 list(string))],
   [-collection=>'Collection',-keys=>
    q(skey1 string, skey2 string, skey3 string, skey4 string,
      lkey1 list(string), lkey2 list(string), lkey3 list(string))],
   [-collection=>'Collection',-keys=>
    q(skey1 string, skey2 string, skey3 string, skey4 string,
      lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))],
  );

for my $i (0..$#registers) {
  for my $j (0..$#registers) {
    my $registry=test
      ('merge '.($i+1).' onto '.($j+1).' registrations - single collection',
       [@registers[0..$i]],[@registers[0..$j]],[@collections[max($i,$j)]]);
  }
}

# Multiple collection tests
my @registers=
  ([-collection=>'Collection1',-keys=>q(skey1 string)],
   [-collection=>'Collection2',-keys=>q(skey2 string)],
   [-collection=>'Collection3',-keys=>q(skey3 string)],
   [-collection=>'Collection4',-keys=>q(skey4 string)],
   [-collection=>'Collection5',-keys=>q(lkey1 list(string))],
   [-collection=>'Collection6',-keys=>q(lkey2 list(string))],
   [-collection=>'Collection7',-keys=>q(lkey3 list(string))],
   [-collection=>'Collection8',-keys=>q(lkey4 list(string))],
  );
my @collections=
  ([-collection=>'Collection1',-keys=>q(skey1 string)],
   [-collection=>'Collection2',-keys=>q(skey2 string)],
   [-collection=>'Collection3',-keys=>q(skey3 string)],
   [-collection=>'Collection4',-keys=>q(skey4 string)],
   [-collection=>'Collection5',-keys=>q(lkey1 list(string))],
   [-collection=>'Collection6',-keys=>q(lkey2 list(string))],
   [-collection=>'Collection7',-keys=>q(lkey3 list(string))],
   [-collection=>'Collection8',-keys=>q(lkey4 list(string))],
  );
for my $i (0..$#registers) {
  for my $j (0..$#registers) {
    my $registry=test
      ('merge '.($i+1).' onto '.($j+1).' registrations - different collections',
       [@registers[0..$i]],[@registers[0..$j]],[@collections[0..max($i,$j)]]);
  }
}

# Multiple keys and collections
my $registry=test
  ('merge 3 onto 3 registrations - different keys and collections - all scalar',
   [[-collection=>'Collection1',-keys=>q(skey2 string)],
    [-collection=>'Collection2',-keys=>q(skey4 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey3 string)],
    [-collection=>'Collection4',-keys=>q(skey4 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string, skey2 string)],
    [-collection=>'Collection2',-keys=>q(skey3 string, skey4 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
    [-collection=>'Collection4',-keys=>q(skey4 string)],
  ],
  );
my $registry=test
  ('merge 3 onto 3 registrations - different keys and collections - all list',
   [[-collection=>'Collection1',-keys=>q(lkey2 list(string))],
    [-collection=>'Collection2',-keys=>q(lkey4 list(string))],
    [-collection=>'Collection3',-keys=>q(lkey3 list(string))],
   ],
   [[-collection=>'Collection1',-keys=>q(lkey1 list(string))],
    [-collection=>'Collection2',-keys=>q(lkey3 list(string))],
    [-collection=>'Collection4',-keys=>q(lkey4 list(string))],
   ],
   [[-collection=>'Collection1',-keys=>q(lkey1 list(string), lkey2 list(string))],
    [-collection=>'Collection2',-keys=>q(lkey3 list(string), lkey4 list(string))],
    [-collection=>'Collection3',-keys=>q(lkey3 list(string))],
    [-collection=>'Collection4',-keys=>q(lkey4 list(string))],
  ],
  );
my $registry=test
  ('merge 3 onto 3 registrations - different keys and collections - mixed scalar and list',
   [[-collection=>'Collection1',-keys=>q(skey2 string, lkey2 list(string))],
    [-collection=>'Collection2',-keys=>q(skey4 string, lkey4 list(string))],
    [-collection=>'Collection3',-keys=>q(skey3 string, lkey3 list(string))],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string, lkey1 list(string))],
    [-collection=>'Collection2',-keys=>q(skey3 string, lkey3 list(string))],
    [-collection=>'Collection4',-keys=>q(skey4 string, lkey4 list(string))],
   ],
   [[-collection=>'Collection1',-keys=>
     q(skey1 string, skey2 string, lkey1 list(string), lkey2 list(string))],
    [-collection=>'Collection2',-keys=>
     q(skey3 string, skey4 string, lkey3 list(string), lkey4 list(string))],
    [-collection=>'Collection3',-keys=>q(skey3 string, lkey3 list(string))],
    [-collection=>'Collection4',-keys=>q(skey4 string, lkey4 list(string))],
  ],
  );

done_testing();
