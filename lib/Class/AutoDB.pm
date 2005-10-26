package Class::AutoDB;
# $Id: AutoDB.pm,v 1.46 2005/07/15 23:08:10 ccavnor Exp $
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use DBI;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Globals;
use Class::AutoDB::Connect;
use Class::AutoDB::Database;
use Class::AutoDB::Registry;
use Class::AutoDB::RegistryDiff;
our $VERSION = '0.092';

@ISA = qw(Class::AutoClass Class::AutoDB::Connect Class::AutoDB::Database);

@AUTO_ATTRIBUTES=qw(read_only read_only_schema
		    object_table registry
		    session cursors
		    _db_cursor);
@OTHER_ATTRIBUTES=qw(server=>'host');
%SYNONYMS=();
Class::AutoClass::declare(__PACKAGE__);

use vars qw($AUTO_REGISTRY);	# TODO: move to Globals
$AUTO_REGISTRY=new Class::AutoDB::Registry;

sub auto_register {
  my($args)=@_;
  $AUTO_REGISTRY->register($args);
}
our $GLOBALS=Class::AutoDB::Globals->instance();

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $GLOBALS->autodb($self) unless $GLOBALS->autodb;
  return unless $self->is_connected; # connection handled in Class::AutoDB::Connect
  my $find=$args->find;
  my $get=$args->get;
  unless ($find) {
    $self->manage_registry($args);
  } else {
    $self->manage_query($find,$args);
  }
}
sub register {
  my $self=shift;
  $self->registry->register(@_);
}
sub put_objects {		# put all objects
  my($self)=@_;
  my $oid2obj=$GLOBALS->oid2obj;
  my $registry=$self->registry;
  while(my($oid,$obj)=each %$oid2obj) {
    next if $obj==$registry;	# registry takes care of itself
    $obj->put;
  }
}
sub manage_query {
#  my($self,$find,$args)=@_;
#  # have to make another AutoDB to serve as session object
#  $args->set(-find=>0,-get=>0);	# so session object won't run query
#  my $session=new Class::AutoDB($args);
#  $self->session($session);
#  # TODO: now run the query
#  $self->find($find);
#  return $self unless $get;
#  return $self->get_all if $get;
}

sub manage_registry {
  my($self,$args)=@_;
  # grab schema modification parameters
  my $read_only_schema=$self->read_only_schema || $self->read_only;
  my $drop=$args->drop;
  my $create=$args->create;
  my $alter=$args->alter;
  my $index=$args->index;
  my $op_count=($create>0)+($alter>0)+($drop>0);
  $self->throw("It is illegal to set more than one of -create, -alter, -drop") if $op_count>1;
  $self->throw("Schema changes not allowed by -read_only or -read_only_schema setting") 
    if $op_count && $read_only_schema;

  my $registry=$self->registry || $self->registry($AUTO_REGISTRY);
  $registry->autodb($self);
  $registry->get;

  # do create first, since it changes schema
  $self->create($index) if $create || (!$self->exists && !$read_only_schema);
  
  $registry->merge;		# merge current and saved versions. computes diff.

  # do drop here, since it needs merged schema. Note return!
  $self->drop,return if $drop; 

  my $diff=$registry->diff;
  my $schema_changed=!$diff->is_sub || !$self->exists;
  if ($schema_changed) {	# in-memory schema adds something to saved schema
    # inconsistent schemas cannot be fixed!
    $self->throw("In-memory and saved registries are inconsistent") unless $diff->is_consistent;
    # no changes allowed if read_only
    $self->throw("In-memory registry adds to saved registry, but schema changes are not allowed by -read_only or -read_only_schema setting") if $read_only_schema;
    # no chages allowed if -alter=>0
    $self->throw("In-memory registry adds to saved registry, but schema alteration prevented by -alter=>0") if $registry->saved && $alter eq 0;
    $self->throw("Schema does not exist, but schema creation prevented by -create=>0 and -alter=>0") if !$registry->saved && $alter eq 0;
    # default changes only if -alter not set -- new collections only
    $self->throw("Some collections are expanded in-memory relative to saved registry.  Must set -alter=>1 to change saved registry") if $diff->has_expanded && !defined $alter;
    # one final check, just in case...
    $self->throw("Software error: need to alter schema, but -alter=>0. Should have been caught earlier") if $alter eq 0;
    $self->alter;
  }
}

1;

__END__

=head1 NAME

Class::AutoDB - Almost automatic object persistence -- MySQL only for
now

=head1 SYNOPSIS

This class works closely with Class::AutoClass to provide almost
transparent object persistence.

=head3 Define class that that uses AutoDB

Person class with attributes 'name', 'sex', 'hobbies', and 'friends',
where 'friends' is a list of Persons.

 package Person;
 use Class::AutoClass;
 @ISA=qw(Class::AutoClass);
   
 @AUTO_ATTRIBUTES=qw(name sex friends);
 %AUTODB=
   (-collection=>'Person',
    -keys=>qq(name string, sex string, friends list(object)));
 Class::AutoClass::declare(__PACKAGE__);

=head3 Store new objects

 use Class::AutoDB;
 use Person;
 my $autodb=new Class::AutoDB(-database=>'test');
 my $joe=new Person(-name=>'Joe',-sex=>'male');
 my $mary=new Person(-name=>'Mary',-sex=>'female');
 my $bill=new Person(-name=>'Bill',-sex=>'male');
 # Set up friends lists
 $joe->friends([$mary,$bill]);
 $mary->friends([$joe,$bill]);
 $bill->friends([$joe,$mary]);
 $autodb->put_objects;           # store objects in database

=head3 Retrieve existing objects

 use Class::AutoDB;
 use Person;
 my $autodb=new Class::AutoDB(-database=>'test');
 
 my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe'); # run query
 print "Number of Joe's in database: ",$cursor->count,"\n";
 while (my $joe=$cursor->get_next) {                # loop getting objects
   # $joe is a Person object -- do what you want with it
   my $friends=$joe->friends;
   for my $friend (@$friends) {
     my $friend_name=$friend->name;
     print "Joe's friend is named $friend_name\n";
   }
 }

-- OR -- 

=head3 Get data in one step rather than via loop

 use Class::AutoDB;
 use Person;
 my $autodb=new Class::AutoDB(-database=>'test');
 my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
 my @joes=$cursor->get;

-- OR -- 

=head3 Run query and get data in one step

 use Class::AutoDB;
 use Person;
 my $autodb=new Class::AutoDB(-database=>'test');
 my @joes=$autodb->get(-collection=>'Person',-name=>'Joe');

	---------------------------------
	Not yet implemented:
	Delete existing objects
	---------------------------------	
	 use Class::AutoDB;
	 use Person;
	 my $autodb=new Class::AutoDB(-database=>'test');
	 my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
	 while (my $joe=$cursor->get_next) { 
	   $autodb->del($joe);
	 }
	---------------------------------	

=head1 DESCRIPTION

This class implements a simple object persistence mechanism. It is
designed to work with Class::AutoClass.

=head2 Persistence model

This is how you're supposed to imagine the system works. The section on
Current Design explains how it really works at present.

Objects are stored in I<collections>. Each collection has any number of
search keys, which you can think of as attributes of an object or
columns of a relational table. You can search for objects in the
collection by specifying values of search keys. For example

my
$cursor=$autodb-E<gt>find(-collection=E<gt>'Person',-name=E<gt>'Joe');

finds all objects in the 'Person' collection whose 'name' key is 'Joe'.
If you specify multiple search keys, the values are ANDed.

	---------------------------------
	Not yet implemented:
	---------------------------------	
	The 'find' method also allows almost raw SQL
	queries with the caveat that these are very closely tied to the
	implementation and will not be portable if we ever change the
	implementation.
	---------------------------------	

A collection can contain objects from many different classes. (This is
Perl after all -- what else would you expect ??!!)

	---------------------------------
	Not yet implemented:
	---------------------------------	
	To limit a search to objects of a specific class,
	you can pass a 'class' parameter to find. In fact, you can search for
	objects of a given class independent of the collection by specifying a
	'class' parameter without a 'collection'.
	---------------------------------	

	---------------------------------
	Not yet implemented:
	---------------------------------	
	When you create an object, the system
	automatically stores it in the database at an 'appropriate' time,
	presently just before Perl destroys the in-memory copy of the object.
	You can also store objects sooner. When you update an object, it gets
	marked as such, and is likewise automatically updated in the database.
	Again, you can do the update manually if you prefer.
	---------------------------------	

You can store specific objects in the database using the 'put' method
on an object or store all objects using the 'put_objects' method on
AutoDB.

	---------------------------------
	Not yet implemented:
	---------------------------------	
	put_objects' consults the put_policy to
	decide which objects to store.
	---------------------------------

 $object->put;            # store one object
 $autodb->put_objects;    # store all objects

=head2 Set up classes to use AutoDB

To use the mechanism, you define the %AUTODB variable in your AutoClass
definition. See Class::AutoClass. If you do not set %AUTODB, or set it
to undef or (), auto-persistence is turned off for your class.

	---------------------------------
	Not yet implemented
	---------------------------------	
	In the simplest case, you can simply set
	
	%AUTODB=(1);
	
	This will cause your class to be persistent, using the default
	collection name and without any search keys.
	---------------------------------

More typically, you set %AUTODB to a HASH of the form

  %AUTODB=(
    -collection=>'Person', 
    -keys=>qq(name string, sex string, friends list(object)));

-collection is the name of the collection that will be used to store
objects of your class (collection names must be E<lt>= 255 characters),
and

-keys is a string that defines the search keys that will be defined for
the class.

The 'keys' string consists of attribute, data type pairs. Each
attribute is generally an attribute defined in the AutoClass
@AUTO_ATTRIBUTES or @OTHER_ATTRIBUTES variables. Technically, it's the
name of a method that can be called with no arguments. The value of an
attribute must be a scalar, an object reference, or an ARRAY (or list)
of such values.

The data type can be 'string', 'integer', 'float', 'object', 
[not yet implemented: any legal MySQL column type], or the phrase list(E<lt>data
typeE<gt>), eg, 'list(integer)'. These are translated into MySQL types
as follows:

 ----------------------------------
 | AutoDB type    | MySQL type    |
 ----------------------------------
 |  string        |  longtext     |
 |  integer       |  int          |
 |  float         |  double       |
 |  object        |  bigint       |
 |                | (unsigned)    |
 ----------------------------------

The 'keys' parameter can also be an array of attribute names, eg,

-keys=E<gt>[qw(name sex)]

in which case the data type of each attribute is assumed to be
'string'. This works in many cases even if the data is really numeric.

The types 'object' and 'list(object)' only work on objects whose
persistence is managed by our Persistence mechanisms.

The 'collection' value may also be an array of collection names (and
may be called 'collections') in which case the object is stored in all
the collections.

A subclass need not define %AUTODB, but may instead rely on the value
set by its super-classes. If the subclass does define %AUTODB, its
values are 'added' to those of its super-classes. Thus, if the suclass
uses a different collection than its super-class, the object is stored
in both. It is an error for a subclass to define the type of a search
key differently than its super-classes. It is also an error for a
subclass to inherit a search key from multiple super-classes with
different types We hope this situation is rare!

Technically, %AUTODB is a parameter list for the register method of
Class::AutoDB. See that method for more details. Some commonly used
paramters are

	---------------------------------
	Not yet implemented
	---------------------------------	
	-transients: an array of attributes that should not be stored. This is
	useful for objects that contain computed values or other information of
	a transient nature.
	
	-auto_gets: an array of attributes that should be automatically
	retrieved when this object is retrieved. These should be attributes
	that refer to other auto-persistent objects. This useful in cases where
	there are attributes that are used so often that it makes sense to
	retrieve them as soon as possible.
	---------------------------------
	
=head2 Using AutoDB in your code

After setting up your classes to use AutoDB, here's how you use the
mechanism.

The first step is to connect your program to the database. This is
accomplished via the 'new' method.

Then you typically retrieve some number of "top level" objects
explcitly by running a query. This is accomplished via the 'find' and
'get' methods (there are several flavors of 'get'). Then, you operate
on objects as usual. If you touch an object that has not yet been
retrieved from the database, the system will automatically get it for
you.

	---------------------------------
	Not yet implemented
	---------------------------------	
	You can also manually retrieve objects at
	any time by running 'get'.
	---------------------------------

	---------------------------------
	Not yet implemented
	---------------------------------	
	You can create new objects as usual and they will
	be automatically written to the database when you're done with them.
	More precisely, Class::AutoDB::Object::DESTROY writes the object to the
	database when Perl determines that the in-memory representation of the
	object is no longer needed. This is guaranteed to happen when the
	program terminates if not before. You can also manually write objects
	to the database earlier if you so desire by running the 'put' method on
	them. If you override DESTROY, make sure you call
	Class::AutoDB::Object::DESTROY in your method.
	
	You can modify objects as usual and the system will take care of
	writing the updates to the database, just as it does for new objects.
	---------------------------------

You can store specific objects in the database using the 'put' method
on an object or store all objects using the 'put_objects' method on
AutoDB. 

	---------------------------------
	Not yet implemented
	---------------------------------	
	'put_objects' consults the put_policy to
	decide which objects to store.
	---------------------------------

 $object->put;            # store one object
 $autodb->put_objects;    # store all objects

=head2 Flavors of 'new', 'find', and 'get'

The examples in the SYNOPSIS use variables named $autodb, $cursor,
$joe, and @joes among others. These names reflect the various stages of
data access that arise.

The first step is to connect to the database. This is accomplished by
'new'.

Next a query is sent to the database and executed. This is typically
accomplished by invoking 'find' on an AutoDB object. The resulting
object (called $cursor in the SYNOPSIS) is called a 'cursor' object. A
cursor object's main purpose is to enable data access. (DBI
afficionados will recogonize that it's possible to 'prepare' a query
before executing it. This is done under the covers here.)

Finally data is retrieved. This is typically accomplished by invoking
'get_next' or 'get' on a cursor object. Data can be retrieved one
object at a time (via 'get_next') or all at once (via 'get'). As a
convenience, you can do the 'find' and 'get' in one step, by invoking
'get' on an AutoDB object.

The query executed by 'find' can either be a simple key based search,
or [not yet implemented: an almost raw, arbitrarily complex SQL query].
The former is specified by providing key=E<gt>value pairs as was done
in the SYNOPSIS, eg,

$cursor=$autodb-E<gt>find(-collection=E<gt>'Person',-name=E<gt>'Joe',-sex=E<gt>'male');

The key=E<gt>value pairs are ANDed as one would expect. The above query
retrieves all Persons whose name is Joe and sex is male.

	---------------------------------
	Not yet implemented
	---------------------------------	
	'find' can also be invoked on a cursor object.
	The effect is to AND the new query with the old. This only works with
	queries expressed as key=E<gt>value pairs, and not raw SQL, since
	conjoining raw SQL is a bear.
	---------------------------------

	---------------------------------
	Not yet implemented
	---------------------------------	
	The raw form is specifed by providing a SQL query
	(as a string) that lacks the SELECT phrase, eg,
	
	$cursor=$autodb-E<gt>find(qq(FROM Person WHERE name="Joe" AND
	sex="male"));
	
	To use this form, you have to understand the relational database schema
	generated by AutoDB. This is not portable across implementations, It's
	main value is to write complex queries that cannot be represented in
	the key=E<gt>value form. For example
	
	 $cursor=$autodb->find(qq(FROM Person p, Person friend, Person_friends friends
	 			 WHERE p.name="Joe" AND 
	 			 (friend.name="Mary" OR friend.name="Bill") AND
	 			 friends.person=p));
	---------------------------------

=head2 Creating and initializing the database

Before you can use AutoDB, you have to create a MySQL database that
will hold your data. We do not provide a means to do this here, since
you may want to put your AutoDB data in a database that holds other
data as well. The database can be empty or not. AutoDB creates all the
tables it needs -- you need not (and should not create) these yourself.

B<Important note>: Hereafter, the term 'database' refers to the tables
created by AutoDB. Phrases like 'create the database' or 'initialize
the database' refer to these tables only, and not the entire MySQL
database that contains the AutoDB database.

Methods are provided to create or drop the entire database (meaning, of
course, the AutoDB database, not the MySQL database) or individual
collections.

AutoDB maintains a registry that describes the collections stored in
the database. Registration of collections is usually handled by
AutoClass behind the scenes as class definitions are encountered. The
system consults the registry when running queries, when writing objects
to the database, and when modifying the database schema.

When 'new' connects to the database, it reads the registry saved from
the last time AutoDB ran. It merges this with an in-memory registry
that generally reflects the currently loaded classes. 'new' merges the
registries, and stores the result for next time if the new registry is
different from the old.

=head2 Current Design

Caveat: The present implementation assumes MySQL. It is unclear how
deeply this assumption affects the design.

Every object is stored as a BLOB constructed by Data::Dumper. The
database contains a single 'object table' for the entire database whose
schema is

 create table _AutoDB (
     oid bigint unsigned not null,
     primary key (oid),
     object longblob
     );

The oid is a unique object identifier assigned by the system. An oid is
a permanent, immutable identifier for the object.

	---------------------------------
	Not yet implemented
	---------------------------------	
	The name of this table can be chosen when the
	database is created. '_AutoDB' is the default.
	---------------------------------

For each collection, there is one table we call the base table that
holds scalar search keys, and one table per list-valued search keys.
The name of the base table is the same as the name of the collection;
there is no way to change this at present. For our Person example, the
base table would be

 create table Person (
     oid bigint unsigned not null,     --- foreign key pointing to _AutoDB
     primary key (oid),                --- also primary key here
     name longtext,
     sex longtext
     );

If a Person has a significant_other (also a Person), the table would
look like this:

 create table Person (
     oid bigint unsigned not null,     --- foreign key pointing to _AutoDB
     primary key (oid),                --- also primary key here
     name longtext,
     sex longtext
     significant_other bigint unsigned --- foreign key pointing to _AutoDB
     );

The data types specified in the 'keys' parameter are used to define the
data types of these columns. They are also used to ensure correct
quoting of values bound into SQL queries. It is safe to use 'string' as
the data type even if the data is numeric unless you intend to run
'raw' SQL queries against the database and want to do numeric
comparisons.

For each list valued search key, eg, 'friends' in our example, we need
another table which (no surprise) is a classic link table. The name is
constructed by concatenating the collection name and key name, with a
'_' in between.

 create table Person_friends (
     oid bigint unsigned not null,  --- foreign key pointing to _AutoDB
     friends bigint unsigned        --- foreign key pointing to _AutoDB
                                    --- (will be a Person)
     );

A small detail: since the whole purpose of these tables is to enable
querying, indexes are created for each column by default (indexes can
be turned off by specifiying index=>0 to the AutoDB constructor).

When the system stores an object, it converts any object references
contained therein into the oids for those objects. In other words,
objects in the database refer to each other using oids rather than the
in-memory object references used by Perl. There is no loss of
information since an oid is a permanent, immutable identifier for the
object.

When an object is retrieved from the database, the system does NOT
immediately process the oids it contains. Instead, the system waits
until the program tries to access the referenced object at which point
it automatically retrieves the object from the database. Options are
provided to retrieve oids earlier.

If a program retrieves the same oid multiple times, the system short
circuits the database access and ensures that only one copy of the
object exists in memory at any point in time. If this weren't the case,
a program could end up with two objects representing Joe, and an update
to one would not be visible in the other. If both copies were later
stored, one update would be lost. The core of the solution is to
maintain an in-memory hash of all fetched objects (keyed by oid). The
software consults this hash when asked to retrieve an object; if the
object is already in memory, it is returned without even going to the
database.

=head1 BUGS and WISH-LIST

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/AutoDB.html#bugs_and_wishlist> 

=head1 METHODS and FUNCTIONS

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/AutoDB.html#methods_and_functions> 

=cut