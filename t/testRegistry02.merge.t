use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Test::Deep;
use Class::AutoClass::Args;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use testRegistry01;

# Test Class::AutoDB::Registry
# Test merge.  
# Uses undocumented interface to dummy up 'saved' registry versions to
#   enable testing without touching the database

sub test {
  my($testname,$current,$saved,$collections)=@_;
  my $registry=new Class::AutoDB::Registry;

  # create current and saved registry versions for testing
  my $version=new Class::AutoDB::RegistryVersion;
  for my $reg (@$current) {
    my @args=@$reg;
    push(@args,(-class=>'testRegistryTop')); # to test class2colls
    $version->register(@args);
  }
  $registry->current($version);	# undocumented interface
  my $version=new Class::AutoDB::RegistryVersion;
  for my $reg (@$saved) {
    my @args=@$reg;
    push(@args,(-class=>'testRegistryTop')); # to test class2colls
    $version->register(@args);
  }
  $registry->saved($version);	# undocumented interface

  $registry->merge;
  my $t_saved=$registry->saved;	# undocumented interface

  # Compute the collections that should have been registered
  my @collections;
  for my $reg (@$collections) {
    my $args=new Class::AutoClass::Args($reg);
    my $registration=new Class::AutoDB::Registration($args);
    my $collection=new Class::AutoDB::Collection(-name=>$args->collection,
						 -register=>$registration);
    push(@collections,$collection);
  }
  my @t_collections=$t_saved->collections;
  @collections=sort {$a->name cmp $b->name} @collections;
  @t_collections=sort {$a->name cmp $b->name} @t_collections;
  is_deeply(\@t_collections,\@collections,"$testname: collections: objects");

  # Test class2colls method (assumes all registrations are on testRegistryTop)
  my $class='testRegistryTop';
  my $t_class_colls=$t_saved->class2colls('testRegistryTop') || []; # undocumented interface
  cmp_bag($t_class_colls,\@collections,"$testname: class2colls: objects");

  $registry;
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
  );
my @collections=
  ([-collection=>'Collection',-keys=>q(skey1 string)],
   [-collection=>'Collection',-keys=>q(skey1 string, skey2 string)],
   [-collection=>'Collection',-keys=>q(skey1 string, skey2 string, skey3 string)],
   [-collection=>'Collection',-keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)],
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
  );
my @collections=
  ([-collection=>'Collection1',-keys=>q(skey1 string)],
   [-collection=>'Collection2',-keys=>q(skey2 string)],
   [-collection=>'Collection3',-keys=>q(skey3 string)],
   [-collection=>'Collection4',-keys=>q(skey4 string)],
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
  ('merge 3 onto 3 registrations - different keys and collections',
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

