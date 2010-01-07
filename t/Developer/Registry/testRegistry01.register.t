use t::lib;
use strict;
use Test::More;
use Test::Deep;
use Class::AutoClass::Args;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use testRegistry01;

# Test Class::AutoDB::Registry
# Simple black box testing of the interface

sub test {
  my($testname,$registers,$collections)=@_;
  my $registry=new Class::AutoDB::Registry;
  for my $reg (@$registers) {
    my @args=@$reg;
    push(@args,(-class=>'testRegistryTop')); # to test class2collections
    $registry->register(@args);
  }
  # Compute the number and names of collections that should have been registered
  my %collections;
  if ($collections) {		# compute from $collections param
    for my $reg (@$collections) {
      my $args=new Class::AutoClass::Args($reg);
      my $registration=new Class::AutoDB::Registration($args);
      my $collection=new Class::AutoDB::Collection(-name=>$args->collection,
						   -register=>$registration->keys);
      $collections{$collection->name}=$collection;
    }
  } else {			# compute from registrations
    for my $reg (@$registers) {
      my @args=@$reg;
      my $registration=new Class::AutoDB::Registration(@args);
      my $names=$registration->collnames;
      for my $name (@$names) {
	$collections{$name}=$name;
      }}}
  my @names=keys %collections;

  # Test collections method
  my @t_collections=$registry->collections;
  my $t_collections=$registry->collections;
  my @t_names=map {$_->name} @t_collections;
  is_deeply(\@t_names,\@names,"$testname: collections as ARRAY: count");
  my @t_names=map {$_->name} @$t_collections;
  is_deeply(\@t_names,\@names,"$testname: collections as ARRAY ref: count");

  # Test collection method
  my @t_names=map {$registry->collection($_)->name} keys %collections;
  is_deeply(\@t_names,\@names,"$testname: collection: names");
  if ($collections) {
    is_deeply(\@t_collections,[values %collections],"$testname: collections as ARRAY: objects");
    is_deeply($t_collections,[values %collections],"$testname: collections as ARRAY ref: objects");
    # Test collection method
    my %t_collections;
    @t_collections{keys %collections}=map {$registry->collection($_)} keys %collections;
    is_deeply(\%t_collections,\%collections,"$testname: collection: objects");
  }
  # Test class2collections method (assumes all registrations are on testRegistryTop
  my $class='testRegistryTop';
  my $class_colls=$registry->class2collections('testRegistryTop') || [];
  my @t_names=map {$_->name} @$class_colls;
  cmp_bag(\@t_names,\@names,"$testname: class2collections: names");
  if ($collections) {
    cmp_bag($class_colls,[values %collections],"$testname: class2collections: objects");
  }

  $registry;
}
  
# Tests start here
#goto skip;

my $registry=new Class::AutoDB::Registry;
is(ref $registry,'Class::AutoDB::Registry','empty collection: new');
is($registry->autodb,undef,'empty collection: default autodb');
is($registry->oid,1,'empty collection: default oid');

# Test boundary cases for registrations
my $registry=test
  ('register 0 registrations',
   [],
   [],
  );
my $registry=test
  ('register 1 registration - single collection',
   [[-collection=>'Collection',-keys=>q(skey1 string)],
   ],
   [[-collection=>'Collection',-keys=>q(skey1 string)],
   ],
  );
my $registry=test
  ('register 2 registrations - single collection',
   [[-collection=>'Collection',-keys=>q(skey1 string)],
    [-collection=>'Collection',-keys=>q(skey2 string)],
   ],
   [[-collection=>'Collection',-keys=>q(skey1 string, skey2 string)],
   ],
  );
my $registry=test
  ('register 3 registrations - single collection',
   [[-collection=>'Collection',-keys=>q(skey1 string)],
    [-collection=>'Collection',-keys=>q(skey2 string)],
    [-collection=>'Collection',-keys=>q(skey3 string)],
   ],
   [[-collection=>'Collection',-keys=>q(skey1 string, skey2 string, skey3 string)],
   ],
  );
my $registry=test
  ('register 4 registrations - single collection',
   [[-collection=>'Collection',-keys=>q(skey1 string)],
    [-collection=>'Collection',-keys=>q(skey2 string)],
    [-collection=>'Collection',-keys=>q(skey3 string)],
    [-collection=>'Collection',-keys=>q(skey4 string)],
   ],
   [[-collection=>'Collection',-keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)],
   ],
  );
my $registry=test
  ('register 1 registration - different collections',
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
   ],
  );
my $registry=test
  ('register 2 registrations - different collections',
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
   ],
  );
my $registry=test
  ('register 3 registrations - different collections',
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
   ],
  );
my $registry=test
  ('register 4 registrations - different collections',
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
    [-collection=>'Collection4',-keys=>q(skey4 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
    [-collection=>'Collection4',-keys=>q(skey4 string)],
   ],
  );

my $registry=test
  ('register 4 registrations - different keys and collections',
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection1',-keys=>q(skey2 string)],
    [-collection=>'Collection2',-keys=>q(skey3 string)],
    [-collection=>'Collection2',-keys=>q(skey4 string)],
   ],
   [[-collection=>'Collection1',-keys=>q(skey1 string, skey2 string)],
    [-collection=>'Collection2',-keys=>q(skey3 string, skey4 string)],
   ],
  );

# Test inheritance of registrations
sub test_inheritance {
  my($registry,$register,$top,$left,$right,$bottom,$testname)=@_;
  $registry->register($register);
  test_inheritance1($registry,'testRegistryTop',$top,"$testname: top");
  test_inheritance1($registry,'testRegistryLeft',$left,"$testname: left");
  test_inheritance1($registry,'testRegistryRight',$right,"$testname: right");
  test_inheritance1($registry,'testRegistryBottom',$bottom,"$testname: bottom");
}
sub test_inheritance1 {
  my($registry,$class,$names,$testname)=@_;
  $names or $names=[];
  my $t_collections=$registry->class2collections($class) || [];
  my @t_names=map {$_->name} @$t_collections;
  cmp_bag(\@t_names,$names,$testname);
}

my $registry=new Class::AutoDB::Registry;
test_inheritance($registry,{-class=>'testRegistryTop',-collection=>'CollectionTop'},
		 ['CollectionTop'],
		 undef,undef,undef,
		 'inheritance: register Top',
		 );
test_inheritance($registry,{-class=>'testRegistryLeft',-collection=>'CollectionLeft'},
		 ['CollectionTop'],
		 ['CollectionTop','CollectionLeft'],
		 undef,undef,
		 'inheritance: register Top, Left',
		 );
test_inheritance($registry,{-class=>'testRegistryRight',-collection=>'CollectionRight'},
		 ['CollectionTop'],
		 ['CollectionTop','CollectionLeft'],
		 ['CollectionTop','CollectionRight'],
		 undef,
		 'inheritance: register Top, Left, Right',
		 );
test_inheritance($registry,{-class=>'testRegistryBottom',-collection=>'CollectionBottom'},
		 ['CollectionTop'],
		 ['CollectionTop','CollectionLeft'],
		 ['CollectionTop','CollectionRight'],
		 ['CollectionTop','CollectionLeft','CollectionRight','CollectionBottom'],
		 'inheritance: register Top, Left, Right, Bottom',
		);

# Do it again with multiple collections
my $registry=new Class::AutoDB::Registry;
test_inheritance($registry,
		 {-class=>'testRegistryTop',-collections=>['CollectionTop1','CollectionTop2']},
		 ['CollectionTop1','CollectionTop2'],
		 undef,undef,undef,
		 'inheritance: register 2 Top',
		 );
test_inheritance($registry,
		 {-class=>'testRegistryLeft',-collections=>['CollectionLeft1','CollectionLeft2']},
		 ['CollectionTop1','CollectionTop2'],
		 ['CollectionTop1','CollectionTop2','CollectionLeft1','CollectionLeft2'],
		 undef,undef,
		 'inheritance: register 2 Top, Left',
		 );
test_inheritance($registry,
		 {-class=>'testRegistryRight',
		  -collections=>['CollectionRight1','CollectionRight2']},
		 ['CollectionTop1','CollectionTop2'],
		 ['CollectionTop1','CollectionTop2','CollectionLeft1','CollectionLeft2'],
		 ['CollectionTop1','CollectionTop2','CollectionRight1','CollectionRight2'],
		 undef,
		 'inheritance: register 2 Top, Left, Right',
		 );
test_inheritance($registry,
		 {-class=>'testRegistryBottom',
		  -collections=>['CollectionBottom1','CollectionBottom2']},
		 ['CollectionTop1','CollectionTop2'],
		 ['CollectionTop1','CollectionTop2','CollectionLeft1','CollectionLeft2'],
		 ['CollectionTop1','CollectionTop2','CollectionRight1','CollectionRight2'],
		 ['CollectionTop1','CollectionTop2',
		  'CollectionLeft1','CollectionLeft2',
		  'CollectionRight1','CollectionRight2',
		  'CollectionBottom1','CollectionBottom2'],
		 'inheritance: register 2 Top, Left, Right, Bottom',
		 );

done_testing();
