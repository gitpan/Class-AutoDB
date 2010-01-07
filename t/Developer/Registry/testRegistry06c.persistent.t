use t::lib;
use strict;
use Test::More;
use Test::Deep;
use Class::AutoClass::Args;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use testRegistry06;

# Test Class::AutoDB::Registry
# Fetch empty registry stored by companion test

sub test {
  my($testname,$registry,$collections)=@_;

  # Compute the collections that should have been registered
  my @collections;
  for my $reg (@$collections) {
    my $args=new Class::AutoClass::Args($reg);
    my $registration=new Class::AutoDB::Registration($args);
    my $collection=new Class::AutoDB::Collection(-name=>$args->collection,
						 -register=>$registration);
    push(@collections,$collection);
  }
  my $t_saved=$registry->saved;
  my @t_collections=$t_saved->collections; # undocumented interface
  
  @collections=sort {$a->name cmp $b->name} @collections;
  @t_collections=sort {$a->name cmp $b->name} @t_collections;
  is_deeply(\@t_collections,\@collections,"$testname: collections");

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
test("get empty registry",$registry,[]);

done_testing();
