use lib qw(. t ../lib);
use Test::More qw/no_plan/;
#use Data::Dumper; # only for debugging
use Class::AutoDB;
use Class::AutoDB::Collection;
use Class::AutoDB::Registration;
use IO::Scalar;
use DBI;
use strict;


  my $named_reference_object = new Class::AutoDB::Collection(-name=>'testing');
  my $nameless_reference_object = new Class::AutoDB::Collection;
  
  my($sql, @sql);
  @sql=$named_reference_object->schema;
  is($sql[0],"create table testing (object varchar(10) not null, primary key (object))","test_schema gets create statement by default  (array context)");
  $sql=$named_reference_object->schema;
  is($sql->[0],"create table testing (object varchar(10) not null, primary key (object))","test_schema gets create statement by default (scalar context)");
  @sql=$named_reference_object->schema('create');
  is($sql[0],"create table testing (object varchar(10) not null, primary key (object))","test_schema gets create statement with 'create' arg");
  $sql=$named_reference_object->schema('drop');
  is($sql->[0],"drop table if exists testing","test_schema gets drop statement with 'drop' arg");
  ## UNIMPLEMENTED - skip 
  #$sql=$named_reference_object->schema('alter');
  #is($sql->[0],"alter? you mean fix???","test_schema requires CollectionDiff with 'alter' arg");
  #$sql=$named_reference_object->schema('alter', $diff);
  #is($sql->[0],"alter? you mean fix???","test_schema object gets alter statement with 'alter, CollectionDiff' args");
  

  my $reg1 = new Class::AutoDB::Registration(
                                                  -class=>'Class::Person',
                                                  -collection=>'Person',
                                                  -keys=>qq(name string, sex string, significant_other object, friends list(object)));
  my $reg2 = new Class::AutoDB::Registration(
                                                  -class=>'Class::Plant',
                                                  -collection=>'Flower',
                                                  -keys=>qq(name string, petals int, color string));
  my $diff = Class::AutoDB::CollectionDiff->new(
                                                          -baseline=>Class::AutoDB::Collection->new($reg1),
                                                          -other=>Class::AutoDB::Collection->new($reg2));

  is(ref($named_reference_object), "Class::AutoDB::Collection");
  is(ref($nameless_reference_object), "Class::AutoDB::Collection");

  my $registration=new Class::AutoDB::Registration(
               -class=>'Class::Person',
               -collection=>'Person',
               -keys=>qq(name string, favorite_song string ));

  
  $named_reference_object->register($registration);
  is($named_reference_object->_keys->{name}, "string", "register adds correct registration keys");
  is($named_reference_object->_keys->{favorite_song}, "string", "register adds correct registration keys");
  is($named_reference_object->merge("foo"), undef, "merge only accepts type collectionDiff");

  my $empty_coll1 = Class::AutoDB::Collection->new;
  my $empty_coll2 = Class::AutoDB::Collection->new;
   
  {                                                                                                                                                             
  	my $DEBUG_BUFFER="";                                                                                                                        
  	tie *STDERR, 'IO::Scalar', \$DEBUG_BUFFER;                                                                                                                   
  	my $diff = Class::AutoDB::CollectionDiff->new(-baseline=>$empty_coll1, -other=>$empty_coll2);  
  	eval{ $named_reference_object->merge($diff) };                                                        
  	ok($DEBUG_BUFFER =~ /merging empty collections/, "Cannot merge empty collections");                                     
  	untie *STDERR;                                                                                                                                               
  }
  
  # make sure new keys are correct
  is(keys %{$diff->new_keys}, 2, "new_keys contains correct number of keys");
  is($diff->new_keys->{color}, "string", "new_keys contains correct value");
  is($diff->new_keys->{petals}, "int", "new_keys contains correct value");
  
  # new keys should be merged into baseline                                                                                
  $named_reference_object->merge($diff);
  is($named_reference_object->keys->{petals}, "int", "testing merged collection");
  is($named_reference_object->keys->{color}, "string", "testing merged collection"); 

  $named_reference_object->register($reg2);
  is($named_reference_object->keys->{petals}, "int", "keys() returns correct key");
  is($named_reference_object->keys->{color}, "string", "keys() returns correct key"); 

  my($tables, @tables);
                                                               
  $nameless_reference_object->register($reg1);
  $named_reference_object->register($reg1);
  $named_reference_object->register($reg2);
  
  @tables=$named_reference_object->tables;
  isa_ok($tables[0], "Class::AutoDB::Table", "array returned: ");
  $tables=$named_reference_object->tables;
  isa_ok($tables->[0], "Class::AutoDB::Table", "scalar ref returned: ");
  is($tables->[0]->{name}, "testing", "tables registered with correct name");
  is($tables->[0]->{_keys}->{color}, "string", "table _keys look good");
  is($tables->[0]->{_keys}->{significant_other}, "object", "table _keys look good");
  is($tables->[1]->{name}, "testing_friends", "testing naming convention collectionName_listName upheld");
  is($tables->[1]->{_keys}->{friends}, "object", "$tables->[1] contains list of type object");

  # should get a warning,return if our collection has no name
  {                                                                                                                                                             
  	my $DEBUG_BUFFER="";                                                                                                                        
  	tie *STDERR, 'IO::Scalar', \$DEBUG_BUFFER;
  	eval{ $nameless_reference_object->alter($diff)->[0] };                                                                                     
  	ok($DEBUG_BUFFER =~ /requires a named collection/, "alter() requires a named collection");                                    
  	untie *STDERR;                                                                                                                                               
  }
                                                               
  $named_reference_object->register($reg1);
  is($named_reference_object->alter($diff)->[0],'alter table testing add color longtext,add petals int', 'alter() returns expected alter statement');

