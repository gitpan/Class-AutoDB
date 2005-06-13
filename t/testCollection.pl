use Util;
use Bio::ISB::AutoDB::Registration;
use Bio::ISB::AutoDB::Collection;
use strict;

goto skip;

my $registration1=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key1 string,
	     integer_key1 integer,
	     float_key1 float,
	     object_key1 object,
	     list_string_key1 list(string), 
	     list_integer_key1 list(integer), 
	     list_float_key1 list(float),
	     list_object_key1 list(object)));
my $registration2=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key2 string,
	     integer_key2 integer,
	     float_key2 float,
	     object_key2 object,
	     list_string_key2 list(string), 
	     list_integer_key2 list(integer), 
	     list_float_key2 list(float),
	     list_object_key2 list(object)));
my $registration11=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key1 string,
	     integer_key1 integer,
	     float_key1 float,
	     object_key1 object,
	     list_string_key1 list(string), 
	     list_integer_key1 list(integer), 
	     list_float_key1 list(float),
	     list_object_key1 list(object)));

my $registration_bad=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key1 integer));

my $collection=new Bio::ISB::AutoDB::Collection
  (-name=>'TestCollection',
   -registrations=>[$registration1,$registration2,$registration11]);
my $name=$collection->name; 
#my $registrations=$collection->registrations; 
my $keys=$collection->keys;	# returns hash of key=>type pairs
my $tables=$collection->tables;	# tables that implement this collection

my @sql=$collection->schema;	              # list of SQL statements needed to create collection
my @sql_create=$collection->schema('create'); # same as above
my @sql_drop=$collection->schema('drop');     # list of SQL statements needed to drop collection

my $sql=$collection->schema;	              # list of SQL statements needed to create collection
my $sql_create=$collection->schema('create'); # same as above
my $sql_drop=$collection->schema('drop');     # list of SQL statements needed to drop collection

$|=1;
print '$collection->name=',$name,"\n";
print '$collection->keys='; pr $keys;
print '$collection->schema=',"@sql\n";
print '$collection->schema='; pr $sql;
print '$collection->schema(\'create\')=',"@sql_create\n";
print '$collection->schema(\'create\')='; pr $sql_create;
print '$collection->schema(\'drop\')=',"@sql_drop\n";
print '$collection->schema(\'drop\')='; pr $sql_drop;

print "This one should fail\n";
my $collection=new Bio::ISB::AutoDB::Collection
  (-name=>'TestCollection',
   -registrations=>[$registration1,$registration2,$registration11,$registration_bad]);

skip:

my $registration1=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key1 string,
	     integer_key1 integer,
	     float_key1 float,
	     object_key1 object,
	     list_string_key1 list(string), 
	     list_integer_key1 list(integer), 
	     list_float_key1 list(float),
	     list_object_key1 list(object)));
my $registration2=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key2 string,
	     integer_key2 integer,
	     float_key2 float,
	     object_key2 object,
	     list_string_key2 list(string), 
	     list_integer_key2 list(integer), 
	     list_float_key2 list(float),
	     list_object_key2 list(object)));
my $registration3=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key1 string,
	     integer_key1 integer,
	     list_string_key1 list(string), 
	     list_integer_key1 list(integer), 
	     list_float_key1 list(float),
	     list_object_key1 list(object)));
my $registration4=new Bio::ISB::AutoDB::Registration
  (-class=>'Bio::ISB::TestClass',
   -collection=>'TestCollection',
   -keys=>qq(string_key1 string,
	     integer_key1 string,
	     float_key1 string,
	     object_key1 object,
	     list_string_key1 list(string), 
	     list_integer_key1 list(integer), 
	     list_float_key1 list(float),
	     list_object_key1 list(object)));
my $collection1=new Bio::ISB::AutoDB::Collection (-name=>'TestCollection1');
$collection1->register($registration1);
my $collection2=new Bio::ISB::AutoDB::Collection (-name=>'TestCollection2');
$collection2->register($registration2);
my $collection3=new Bio::ISB::AutoDB::Collection (-name=>'TestCollection3');
$collection3->register($registration3);
my $collection4=new Bio::ISB::AutoDB::Collection (-name=>'TestCollection4');
$collection4->register($registration4);
my $collection5=new Bio::ISB::AutoDB::Collection (-name=>'TestCollection5');
$collection5->register($registration1);

print "Comparing \$collection1 vs. \$collection2\n";
$collection1->cmp_reset;
print "is_consistent=",$collection1->is_consistent($collection2),"\n";
print "is_inconsistent=",$collection1->is_inconsistent($collection2),"\n";
print "is_equivalent=",$collection1->is_equivalent($collection2),"\n";
print "is_different=",$collection1->is_different($collection2),"\n";
print "is_sub=",$collection1->is_sub($collection2),"\n";
print "is_super=",$collection1->is_super($collection2),"\n";
print "is_expanded=",$collection1->is_expanded($collection2),"\n";
print "is_shrunk=",$collection1->is_shrunk($collection2),"\n";

print "Comparing \$collection2 vs. \$collection1\n";
$collection2->cmp_reset;
print "is_consistent=",$collection2->is_consistent($collection1),"\n";
print "is_inconsistent=",$collection2->is_inconsistent($collection1),"\n";
print "is_equivalent=",$collection2->is_equivalent($collection1),"\n";
print "is_different=",$collection2->is_different($collection1),"\n";
print "is_sub=",$collection2->is_sub($collection1),"\n";
print "is_super=",$collection2->is_super($collection1),"\n";
print "is_expanded=",$collection2->is_expanded($collection1),"\n";
print "is_shrunk=",$collection2->is_shrunk($collection1),"\n";

print "Comparing \$collection1 vs. \$collection3\n";
$collection1->cmp_reset;
print "is_consistent=",$collection1->is_consistent($collection3),"\n";
print "is_inconsistent=",$collection1->is_inconsistent($collection3),"\n";
print "is_equivalent=",$collection1->is_equivalent($collection3),"\n";
print "is_different=",$collection1->is_different($collection3),"\n";
print "is_sub=",$collection1->is_sub($collection3),"\n";
print "is_super=",$collection1->is_super($collection3),"\n";
print "is_expanded=",$collection1->is_expanded($collection3),"\n";
print "is_shrunk=",$collection1->is_shrunk($collection3),"\n";

print "Comparing \$collection3 vs. \$collection1\n";
$collection3->cmp_reset;
print "is_consistent=",$collection3->is_consistent($collection1),"\n";
print "is_inconsistent=",$collection3->is_inconsistent($collection1),"\n";
print "is_equivalent=",$collection3->is_equivalent($collection1),"\n";
print "is_different=",$collection3->is_different($collection1),"\n";
print "is_sub=",$collection3->is_sub($collection1),"\n";
print "is_super=",$collection3->is_super($collection1),"\n";
print "is_expanded=",$collection3->is_expanded($collection1),"\n";
print "is_shrunk=",$collection3->is_shrunk($collection1),"\n";

print "Comparing \$collection1 vs. \$collection4\n";
$collection1->cmp_reset;
print "is_consistent=",$collection1->is_consistent($collection4),"\n";
print "is_inconsistent=",$collection1->is_inconsistent($collection4),"\n";
print "is_equivalent=",$collection1->is_equivalent($collection4),"\n";
print "is_different=",$collection1->is_different($collection4),"\n";
print "is_sub=",$collection1->is_sub($collection4),"\n";
print "is_super=",$collection1->is_super($collection4),"\n";
print "is_expanded=",$collection1->is_expanded($collection4),"\n";
print "is_shrunk=",$collection1->is_shrunk($collection4),"\n";

print "Comparing \$collection4 vs. \$collection1\n";
$collection4->cmp_reset;
print "is_consistent=",$collection4->is_consistent($collection1),"\n";
print "is_inconsistent=",$collection4->is_inconsistent($collection1),"\n";
print "is_equivalent=",$collection4->is_equivalent($collection1),"\n";
print "is_different=",$collection4->is_different($collection1),"\n";
print "is_sub=",$collection4->is_sub($collection1),"\n";
print "is_super=",$collection4->is_super($collection1),"\n";
print "is_expanded=",$collection4->is_expanded($collection1),"\n";
print "is_shrunk=",$collection4->is_shrunk($collection1),"\n";

print "Comparing \$collection1 vs. \$collection5\n";
$collection1->cmp_reset;
print "is_consistent=",$collection1->is_consistent($collection5),"\n";
print "is_inconsistent=",$collection1->is_inconsistent($collection5),"\n";
print "is_equivalent=",$collection1->is_equivalent($collection5),"\n";
print "is_different=",$collection1->is_different($collection5),"\n";
print "is_sub=",$collection1->is_sub($collection5),"\n";
print "is_super=",$collection1->is_super($collection5),"\n";
print "is_expanded=",$collection1->is_expanded($collection5),"\n";
print "is_shrunk=",$collection1->is_shrunk($collection5),"\n";

print "Comparing \$collection5 vs. \$collection1\n";
$collection5->cmp_reset;
print "is_consistent=",$collection5->is_consistent($collection1),"\n";
print "is_inconsistent=",$collection5->is_inconsistent($collection1),"\n";
print "is_equivalent=",$collection5->is_equivalent($collection1),"\n";
print "is_different=",$collection5->is_different($collection1),"\n";
print "is_sub=",$collection5->is_sub($collection1),"\n";
print "is_super=",$collection5->is_super($collection1),"\n";
print "is_expanded=",$collection5->is_expanded($collection1),"\n";
print "is_shrunk=",$collection5->is_shrunk($collection1),"\n";


print "done\n";
