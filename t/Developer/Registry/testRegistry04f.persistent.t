use t::lib;
use strict;
use Test::More;
use Test::Deep;
use Class::AutoClass::Args;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use testRegistry04;

# Test Class::AutoDB::Reg
# Fetch registry stored by companion test

sub test {
  my($testname,$registry,$collections)=@_;

  # Compute the collections that should have been registered
  my @collections;
  for my $reg (@$collections) {
    my $args=new Class::AutoClass::Args($reg);
    my $registration=new Class::AutoDB::Registration($args);
    my $collection=new Class::AutoDB::Collection(-name=>$args->collection,
						 -register=>$registration->keys);
    push(@collections,$collection);
  }
  my $t_saved=$registry->saved;
  my @t_collections=$t_saved->collections; # undocumented interface
  
  @collections=sort {$a->name cmp $b->name} @collections;
  @t_collections=sort {$a->name cmp $b->name} @t_collections;
  is_deeply(\@t_collections,\@collections,"$testname");

  # Test class2collections method (assumes all registrations are on testRegistry)
  my $class='testRegistry';
  my $t_class_colls=$t_saved->class2collections($class) || []; # undocumented interface
  cmp_bag($t_class_colls,\@collections,"$testname: class2collections: objects");

  $registry;
}

my $autodb=new Class::AutoDB(-database=>'test');
ok($autodb->is_connected,'Able to connect to test database');
die 'Unable to connect to database' unless $autodb->is_connected;
my $registry=$autodb->registry;
isa_ok($registry,'Class::AutoDB::Registry','registry');

test
  ("get registry with 5 collections",$registry,
   [[-collection=>'Collection1',-keys=>q(skey1 string)],
    [-collection=>'Collection2',-keys=>q(skey2 string)],
    [-collection=>'Collection3',-keys=>q(skey3 string)],
    [-collection=>'Collection4',-keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)],
    [-collection=>'Collection5',-keys=>q(skey5 string)],
   ]);

done_testing();
