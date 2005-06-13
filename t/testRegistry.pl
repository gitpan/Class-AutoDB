use Util;
use Carp;
use Bio::ISB::AutoDB;
use Bio::ISB::AutoDB::Registry;
use strict;

my $autodb=new Bio::ISB::AutoDB(-dsn=>'dbi:mysql:database=ngoodman;host=socks');
my $saved=new Bio::ISB::AutoDB::Registry(-autodb=>$autodb);
my $transient=new Bio::ISB::AutoDB::Registry;
my $registry;

$transient->register
  (-class=>'TestClass',-collection=>'TestCollection_1',
   -keys=>qq(string_key string,integer_key integer,float_key float,object_key object,
	     list_key list(string)));
$transient->register
  (-class=>'TestClass',-collection=>'TestCollection_1',
   -keys=>qq(string_key string,another_key string));

$transient->register
  (-class=>'TestClass',-collection=>'TestCollection_1',
   -keys=>qq(string_key string,another_key string,alter_key string));
$transient->register
  (-class=>'TestClass',-collection=>'TestCollection_1',
   -keys=>qq(another_alter_key string ,alter_list list(string)));
$transient->register
  (-class=>'TestClass',-collection=>'TestCollection_2',
   -keys=>qq(string_key string,another_key string));

$|=1;
#my $registrations=$registry->registrations;
#print "\$registrations="; pr $registrations;
#my $collections=$registry->collections;
#print "\$collections="; pr $collections;
#my $testcollection_1=$registry->collection('TestCollection_1');
#print "\$testcollection_1 (by name)="; pr $testcollection_1;
#my $testcollection_1=$registry->collection($testcollection_1);
#print "\$testcollection_1 (by object)="; pr $testcollection_1;

confess "Saved registry and transient registry are inconsistent" 
  unless $transient->is_consistent($saved);
if (!$transient->is_sub($saved)) {
  my @new_collections=$transient->self_only_collections($saved);
  #  $saved->create(@new_collections);
  my @expanded_collections=$transient->expanded_collections($saved);
  #  $saved->alter(@expanded_collections);
  my @sql=$saved->merge(@new_collections,@expanded_collections);
  $saved->put;
  $saved->do_sql(@sql);
}
$registry=$saved;

print "break here\n";
