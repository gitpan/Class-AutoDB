package Class::AutoDB;
# $Id: AutoDB.pm,v 1.49 2006/05/15 18:38:18 natgoodman Exp $
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use DBI;
use Class::AutoClass;
use Hash::AutoHash::Args;
use Class::AutoDB::Globals;
use Class::AutoDB::Connect;
use Class::AutoDB::Database;
use Class::AutoDB::Registry;
use Class::AutoDB::RegistryDiff;
our $VERSION = '1.11';
$VERSION=eval $VERSION;		# I think this is the accepted idiom..

# NG 09-11-24: move Database first so AutoClass::get will not mask Database::get
#              this breaks the usual rule that AutoClass must be first, but it's okay 
#              since we know Database and Connect do not provide 'new' methods.
#              note also that AutoClass redundant here since Database and Connect
#              both inherit from AutoClass anyway
use base qw(Class::AutoDB::Database Class::AutoDB::Connect Class::AutoClass);

@AUTO_ATTRIBUTES=qw(read_only read_only_schema alter_param index_param
		    object_table registry
		    session cursors
		    _db_cursor);
@OTHER_ATTRIBUTES=qw(server=>'host');
%SYNONYMS=();
Class::AutoClass::declare;

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
  # NG 09-12-05: alter, index needed by register. find, get no longer supported
  my($alter,$index)=@$args{qw(alter index)};
  $self->set(alter_param=>$alter,index_param=>$index);
  $self->manage_registry($args);
  # NG 09-12-05: find, get params no longer supported
  #   my $find=$args->find;
  #   my $get=$args->get;
  #  unless ($find) {
  #    $self->manage_registry($args);
  #  } else {
  #     $self->manage_query($find,$args);
  #   }
}
# NG 09-12-06: rewrote to reduce redundacy with _init_self and to be compatible with 'new'
sub renew {
  my($self,@args)=@_;
  my $args=new Hash::AutoHash::Args(@args);
  $self->reconnect($args);	# disconnect and reconnect
  # set attributes not already set in reconnect
  $self->Class::AutoClass::set_attributes([qw(read_only read_only_schema)],$args);
  $self->_init_self(ref $self,$args);
  return unless $self->is_connected;
  $self;
}
sub register {
  my $self=shift;
  $self->registry->register(@_);
  # NG: 09-12-05: store registry after programmatic change
  #               uses alter, index params from 'new'
  $self->manage_registry
    (new Hash::AutoHash::Args alter=>$self->alter_param,index=>$self->index_param);
}
# NG 09-11-24: extend put_object to put list of objects
# NG 09-12-19: rewrote to avoid $obj->put for cleanup of user-object namespace
sub put_objects {
  my $self=shift;
  my @objects=@_;
  unless (@objects) {		# put all objects if none given
    my $oid2obj=$GLOBALS->oid2obj;
    @objects=values %$oid2obj;
  }
  $self->put(@objects);	# put list of objeccts
}
# sub put_objects {
#   my $self=shift;
#   $self->put(@_), return if @_;	# put list of objeccts
#   # else put all objects
#   my $oid2obj=$GLOBALS->oid2obj;
#   my @objects=values %$oid2obj;
#   $self->put(@objects);
#   my $registry=$self->registry;
#   while(my($oid,$obj)=each %$oid2obj) {
#     next if $obj==$registry;	# registry takes care of itself
#     $obj->put;
#   }
# }
# NG 09-11-24: added 'put' method. first step towards cleaning namespace of user-objects
#              it's okay and useful to leave 'put' method in Object and Oid for users' 
#              convenience, but we should never call it
sub put {
  my $self=shift;
  my $registry=$self->registry;
  for my $obj (@_) {
    # NG 10-02-24: moved this line because
    #              (1) registry never exists as Oid
    #              (2) in perl 5.10, '==' forces stringify
    # next if $obj==$registry;	# registry takes care of itself
    # NG 09-12-19: this line now needed because we stopped doing $obj->put
    #              (Oid has 'put' method that skips the store)
    next if UNIVERSAL::isa($obj,'Class::AutoDB::Oid');
    # NOTE: overload man page suggests comparing refaddrs instead of object.
    #       but comparing objects seems to work, provided $obj NOT Oid!!
    next if $obj==$registry;	# registry takes care of itself. 
    # $obj->put;	        # TODO: don't invoke put method - pollutes namespace!
    # NG 09-12-19: crude 1st attempt to move logic out of user-object
    my $transients=$registry->class2transients(ref $obj);
    my $collections=$registry->class2collections(ref $obj);
    my $oid=Class::AutoDB::Serialize::obj2oid($obj);
    $self->throw("trying to put something non-persistent: $obj") unless $oid;
    Class::AutoDB::Serialize::store($obj,$transients); # store the serialized form
    my @sql=map {$_->put($obj)} @$collections;         # generate SQL to store in collections
    $self->do_sql(@sql);
  }
}
# NG 09-11-29: added 'oid' method. first step towards cleaning namespace of user-objects 
#              it's okay and useful to leave 'oid' method in Object and Oid for users' 
#              convenience, but we should never call it
sub oid {
  my($self,$obj)=@_;
  # $obj->oid;
  # NG 09-12-12: crude 1st attempt to move logic out of user-object
  Class::AutoDB::Serialize::obj2oid($obj);
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
  my $drop=norm0($args->drop);
  my $create=norm0($args->create);
  my $alter=norm0($args->alter);
  my $index=$args->index;
  my $op_count=($create>0)+($alter>0)+($drop>0);
  $self->throw("It is illegal to set more than one of -create, -alter, -drop") if $op_count>1;
  $self->throw("Schema changes not allowed by -read_only or -read_only_schema setting") 
    if $op_count && $read_only_schema;

  my $registry=$self->registry || $self->registry($AUTO_REGISTRY);
  $registry->autodb($self);
  $registry->get;

  # do create first, since it changes schema
  # NG 09-12-27: was creating database if !exists, even when create=>0
  # $self->create($index) if $create || (!$self->exists && !$read_only_schema);
  my $create_ok=!$drop && $alter ne 0 && $create ne 0;
  $self->create($index) if $create || ($create_ok && !$self->exists && !$read_only_schema);
  return if $create eq 0 && !$self->exists;
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
# normalize defined but false values to 0
sub norm0 {defined($_[0] )&&!$_[0]? 0: $_[0];}
1;

__END__

=head1 NAME

Class::AutoDB - Almost automatic object persistence coexisting with human-engineered database

=head1 VERSION

Version 1.11

=head1 SYNOPSIS

  # code that defines persistent class
  #
  package Person;
  use base qw(Class::AutoClass);
  use vars qw(@AUTO_ATTRIBUTES %AUTODB);
  @AUTO_ATTRIBUTES=qw(name sex id friends);
  %AUTODB=
    (collection=>'Person',
     keys=>qq(name string, sex string, id integer));  
  Class::AutoClass::declare;

  ########################################
  # code that uses persistent class - create and store new objects
  #
  use Class::AutoDB;
  use Person;
  my $autodb=new Class::AutoDB(database=>'test'); # open database

  # make some objects. not yet stored in database
  my $joe=new Person(name=>'Joe',sex=>'M',id=>1);
  my $mary=new Person(name=>'Mary',sex=>'F',id=>2);
  my $bill=new Person(name=>'Bill',sex=>'M',id=>3);

  # set up friends lists. each is a list of Person objects
  $joe->friends([$mary,$bill]);
  $mary->friends([$joe,$bill]);
  $bill->friends([$joe,$mary]);

  # store objects in database
  $autodb->put_objects;

  ########################################
  # code that uses persistent class - retrieve existing objects
  #
  use Class::AutoDB;
  use Person;
  my $autodb=new Class::AutoDB(database=>'test');

  # retrieve list of objects
  my @persons=$autodb->get(collection=>'Person');        # everyone
  my @males=$autodb->get(collection=>'Person',sex=>'M'); # just the boys  

  # do something with the retrieved objects, for example, print friends lists
  for my $person (@persons) {
    my @friend_names=map {$_->name} @{$person->friends};
    print $person->name,"'s friends are @friend_names\n";
  }
 
  # retrieve and process objects one-by-one
  my $cursor=$autodb->find(collection=>'Person'); 
  while (my $person=$cursor->get_next) {
    # do what you want with $person, for example, print friends list
    my @friend_names=map {$_->name} @{$person->friends};
    print $person->name,"'s friends are @friend_names\n";
 }

  # connect auto-persistent objects with engineered tables
  # assume database has human-engineered tables
  #   Dept(id int, name varchar(255)), EmpDept(emp_id int, dept_id int)
  # this query retrieves the names of Joe's departments
  use DBI;
  my $dbh=$autodb->dbh;
  my $depts=$dbh->selectcol_arrayref
    (qq(SELECT Dept.name FROM Dept, EmpDept, Person 
        WHERE Dept.id=EmpDept.dept_id AND EmpDept.emp_id=Person.id 
        AND Person.name='Joe'));

=head1 DESCRIPTION

This class works closely with L<Class::AutoClass> to provide almost
transparent object persistence that can coexist with a
human-engineered database. The auto-persistence mechanism provides
hooks for connecting the two parts of the database together.

B<Caveat>: The current version only works with MySQL.

For applications where performance is not pressing, you can use this
class for all your persistent data.  In other cases, you can use it
for structurally complex, but low volume, parts of your database,
while storing performance-critical data in carefully engineered
tables.  This class is also handy for prototyping persistent
applications and lets you incrementally replace auto-persistent
components with engineered tables as your design proceeds.

=head2 Persistence model

This section presents a brief overview of the class.  Please see later
sections for details.

You declare a class to be persistent by defining the %AUTODB variable
in the module.  L<Class::AutoClass> (specifically,
Class::AutoClass::declare) uses %AUTODB to set everything up.

In simple cases, you set %AUTODB to 1, eg,

  %AUTODB=1;

This causes your class to be persistent, but provides no way to search
for objects and no convenient hook for connecting these objects to the
engineered parts of your database (unless a superclass provides these
capabilities).

More typically, you set %AUTODB to a hash of the form

  %AUTODB=(
    collection=>'Person', 
    keys=>qq(name string, sex string, id number));

This associates a persistent collection, called 'Person', with your
class and says that the Person collection has three search keys:
'name', 'sex', and 'id'.  Collections provide a way to search for
objects and are the hooks for connecting auto-persistent objects with
the rest of your database.

After setting up your classes to use Class::AutoDB, you use it as follows.

First you connect your program to the database by running
Class::AutoDB's 'new' method.  Then you typically invoke 'get' or
'find' to retrieve some number of "top level" objects.  Then, you
operate on objects as usual. If you touch an object that has not yet
been retrieved from the database, the system will automatically fetch
it for you.

The retrieval process reconstructs the original object network.  You
never get duplicate copies of a persistent object no matter how many
times you retrieve the object and no matter what path you use to reach
it.  In our running example, it doesn't matter whether you get all
Person objects first and then traverse their friends lists, or get
Person objects one-by-one and and traverse their friends lists as you
go.  The end result is the same: you end up with one copy of each
Person object, and the various friends lists point to these objects as
expected.

You can store specific objects in the database by invoking the 'put'
method on the object (deprecated) or on AutoDB (preferred). You can
store all objects using the 'put_objects' method on AutoDB.

  $joe->put;               # store one object (deprecated form)
  $autodb->put($joe);      # store one object (preferred form)
  $autodb->put_objects;    # store all objects

'put' stores the object and any Perl structures (typically ARRAYs or
HASHes) to which the object points B<except for other persistent
objects>.  The storage process converts references to persistent
objects into a representation (called an 'oid' -- stands for 'object
identifier') that the retrieval process can use later to fetch the
object on demand.

Thus, when 'putting' the 'Joe' object, the software stores Joe's
'name', 'sex', and 'id' (which are simple strings and numbers), and an
ARRAY of oids representing Joe's friends.  Your program is responsible
for making sure each friend object is also stored.

The difference between persistent and non-persistent objects is that
the system treats each persistent object as an independent unit but
considers non-persistent objects to be part of the persistent objects
that point to them.  If two persistent objects point to the same
non-persistent object, the system will store separate copies of the
non-persistent object when you 'put' the persistent ones, and will
retrieve separate copies of the non-persistent object when you
retrieve the persistent ones.  This is usually an error but may be
useful in special circumstances.

Suppose we extend our running example by adding a Name class to
represent the 'name' attribute of Person objects.  If you expect each
Person to have a separate Name object (which seems likely), it will
work fine for Name to be non-persistent.  However, if you want Persons
to share Names, you should declare Name to be persistent.

=head2 Defining a persistent class

You declare a class to be persistent by defining the %AUTODB variable
in the module.  Class:::AutoDB works closely with L<Class::AutoClass>
and in typical usage, Class::AutoClass::declare uses %AUTODB to set
everything up.

There is no way to arrange for some instances of a class to be
persistent while others are not.  Also, there is no way at present for
a subclass to be nonpersistent if any of its superclasses are
persistent.

%AUTODB specifies two properties of the persistent class (both optional).

=over 2

=item 1. Collections

Collections provide a way to search for objects and are the hooks for
connecting auto-persistent objects with the rest of your database.
You can define any number of collections for your class (including
none), and each collection can have any number of search keys (again
including none).

A collection can contain objects from many different classes. (This is
Perl after all -- what else would you expect ??!!) 

=item 2. Transients

Transients are keys of your object that you do not want Class::AutoDB
to store in the database when you 'put' the object.  These may be
values that are computed as needed and kept in the object for
convenience, or items tied to the program's execution (eg, an open
filehandle).  Needless to say, transient keys are not resurrected when
objects are retrieved.

=back

=head3 Collections

Collections contain references to objects (specifically oids), not
objects themselves.  This is why it works to have multiple collections
per class, and multiple classes per collection.

Search keys are typed: valid types are string, integer, float, object,
or the phrase list(<data type>), eg, list(integer). It also works to
use abbreviations for the types; any prefix is fine.  These are
translated into MySQL types as follows:

=over 2

=item * string -> longtext

=item * integer -> int

=item * float -> double

=item * object ->  bigint (unsigned)

=back

The types 'object' and 'list(object)' only work on objects whose
persistence is managed by Class::AutoDB.

For each collection, the system creates a relational table with an
'oid' column to connect the collection to the object being described,
and additional columns for the search keys.  List-valued search keys
are stored in separate link tables.  For our running example, the
system would create the following table:

 Person(oid bigint, name longtext, sex longtext, id int)

If multiple classes use the same collection, it is okay (even
sensible!) for one class to define the search keys, while the other
classes just refer to the collection by name. If multiple classes
define search keys for the collection, the definitions are 'added':
the search keys for the collection are the union of all the
definitions.  It is an error for multiple classes to give different
types to the same search key.

A similar situation arises in class hierarchies.  A subclass inherits
the collections used by its superclasses.  The subclass need not
define %AUTODB, but if it does, its values are 'added' to those of its
superclasses: the system associates the class with the union of the
collections specified by the class and its superclasses; if the
subclass defines additional search keys for some of these collections,
the systems adds these to the search keys defined in the
superclasses. It is an error for a subclass to define the type of a
search key differently than its superclasses.

It is also possible to L<programmatically define collections|"Defining
collections programmatically">, using the 'register' method of AutoDB.

=head3 Forms of %AUTODB 

There are several valid forms for %AUTODB.

=over 2

=item * unset

If you leave %AUTODB unset, the class inherits the persistence
properties of its superclasses.  If all superclasses are
nonpersistent, the class is also nonpersistent.

=item * single false value, eg, %AUTODB=0, or %AUTODB=undef

This is presently illegal. We reserve this form to specify that a
class be nonpersistent even if its superclasses are persistent.

=item * %AUTODB=1

This declares the class to be persistent but defines no collections or
transients. The class uses the collections and transients defined by
its superclasses, if any.  Note that setting %AUTODB to 1 really sets
it to the hash (1=>undef).

=back

The remaining forms set %AUTODB to a hash whose elements specify the
class's collections or transients. 

There are several forms for specifying collections.

=over 2

=item * standard single collection form

The hash has elements 'collection' and 'keys'.  For example 

  %AUTODB=(
    collection=>'Person', 
    keys=>qq(name string, sex string, id integer));

The meaning is obvious: 'collection' gives the name of the collection,
and 'keys' its search keys. 

You can specify 'keys' as a comma-separated string of "key type"
pairs, a HASH of key=>type pairs, or an ARRAY of keys.  In the first
two cases, the type is optional; in all cases, type defaults to
'string'.  Here are some examples.

  keys=>qq(name string, sex string, id integer)
  keys=>'name, sex, id integer'
  keys=>{name=>'string', sex=>'string', id=>'integer'}
  keys=>{name=>'', sex=>'', id=>'integer'}
  keys=>[qw(name sex id)]

=back

The remaining forms can specify any number of collections (including
none or one).  

The examples that follow extend our running example with a second
collection, 'HasName', which contains objects of many classes which
have 'name' attributes.

=over 2

=item * HASH of collections form

The hash has a 'collections' element ('collection' also works) and
does not have a 'keys' element. The 'collections' element is a HASH of
collection-name=>keys pairs.  As above, you can specify the keys as
strings of "key type" pairs, HASHes of key=>type pairs, ARRAYs of
keys, or a single key.

  %AUTODB=(
    collections=>{Person=>{name=>'string', sex=>'string', id=>'integer'},
		  HasName=>'name'});

=item * list of collections form

The hash has a 'collections' element ('collection' also works) and may
have a 'keys' element. The 'keys' element, if present, applies to all
collections.  This can make sense if a base class is defining core
properties of several collections with the expectation that subclasses
will refine the collections with additional keys.

The 'collections' element can be a whitespace- or comma-separated
string of collection names or an ARRAY of collection names.

  %AUTODB=(collections=>'Person HasName');
  %AUTODB=(collections=>[qw(Person HasName)]);

This form is best used when the collections are defined elsewhere.

=back

Transients are specified by a hash elements whose key is
'transients'. In the following examples, imagine that Person objects
have keys 'name_prefix' and 'sex_word'; the former might contain
honorifics like 'Dr' extracted from the name; the latter might be full
word sex descriptors computed from the single letter codes, eg
'female'.

You can specify transients keys as a whitespace- or comma-separated
string of keys, or an ARRAY of keys.

  transients=>qq(name_prefix sex_word)
  transients=>[qw(name_prefix sex_word)]

Putting it together, here are two examples of typical usage.

   %AUTODB=(
    collection=>'Person', 
    keys=>qq(name string, sex string, id integer),
    transients=>qq(name_prefix sex_word));

  %AUTODB=(
    collections=>{Person=>qq(name string, sex string, id integer),
                  HasName=>'name'},
    transients=>[qw(name_prefix sex_word)]);

=head3 Type mismatches

If you store data of the wrong type into a search key, Perl-ish data
conversion occurs.  (It might be better for the software to throw an
error).

=over 2

=item * a non-numeric value stored in a numeric key is converted to 0;
this includes references

=item * a reference stored in a string key is stringified, yielding
something like HASH(0x18a41e0); this is probably not what you had in
mind

=item * any non-persistent value stored in an object key is converted to NULL

=back

=head3 Defining collections programmatically

It is also possible to programmatically define collections using the
'register' method of AutoDB.  Every valid form of %AUTODB also work as
the argument to 'register'. In addition, 'register' can take a 'class'
parameter which specifies a class to be associated with the
collections being defined.

'class' can be a whitespace- or comma-separated string of class names,
or an ARRAY of class names.  Here are two examples.

  $autodb->register(
    collections=>{Person=>qq(name string, sex string, id integer),
                  HasName=>'name'});
  $autodb->register(
    class=>'Person', collections=>'Person, HasName');

When you 'register' new collections or add search keys to existing
ones (as in the first example above), the system creates or alters
database tables as needed to implement your changes.  These effects
are persistent, of course.

When you 'register' new associations between classes and collections
(as in the second example above), these changes are in effect for the
current session only. This makes it possible to dynamically change the
collections into which new objects are put.

=head2 Creating and initializing the database

Before you can use Class::AutoDB, you have to create a MySQL database
that will hold your data. We do not provide a means to do this here,
since you may want to put your AutoDB data in a database that holds
other data as well. The database can be empty or not. AutoDB creates
all the tables it needs -- you need not (and should not) create these
yourself.

B<Important note>: Hereafter, the term 'database' refers to the tables
created by AutoDB. Phrases like 'create the database' or 'initialize
the database' refer to these tables only, and not the entire MySQL
database that contains the AutoDB database.

We provide methods to create or drop the entire database (meaning, of
course, the AutoDB database, not the MySQL database) or to create
individual collections.

Class::AutoDB maintains a registry that describes the collections
stored in the database. The software registers collections as it
encounters class definitions . The system consults the registry when
running queries, when writing objects to the database, and when
modifying the database schema.

When 'new' connects to the database, it reads the registry saved from
the last time Class::AutoDB ran. It merges this with an in-memory
registry that generally reflects the currently loaded classes. 'new'
merges the registries, and stores the result for next time if the new
registry is different from the old.

B<Caveat>: You can only have one active AutoDB object at a time.
Grievous errors will occur if you run 'new' a second time on a
different database.  Sorry.  We will fix this.

=head2 Current design

B<Caveat>: The present implementation assumes MySQL. It is unclear how
deeply this assumption affects the design.

Every object is stored as a BLOB constructed by a L<slightly modified
version of Data::Dumper|"Data::Dumper details">. The database contains
a single 'object table' for the entire database whose schema is

 create table _AutoDB (
   oid bigint unsigned not null,
   primary key (oid),
   object longblob
   );

The oid is a unique object identifier assigned by the system. An oid is
a permanent, immutable identifier for the object.

For each collection, there is one table we call the base table that
holds scalar search keys, and one table per list-valued search key.
The name of the base table is the same as the name of the collection;
there is no way to change this at present. For our Person example, the
base table would be

 create table Person (
   oid bigint unsigned not null,     --- foreign key pointing to _AutoDB
   primary key (oid),                --- also primary key here
   name longtext,
   sex longtext,
   id int
   );

If a Person has a significant_other key (also a Person), the table would
look like this:

 create table Person (
   oid bigint unsigned not null,     --- foreign key pointing to _AutoDB
   primary key (oid),                --- also primary key here
   name longtext,
   sex longtext,
   id int,
   significant_other bigint unsigned --- foreign key pointing to _AutoDB
   );

The data types specified in the 'keys' parameter are used to define the
data types of these columns. They are also used to ensure correct
quoting of values bound into SQL queries. It is safe to use 'string' as
the data type even if the data is numeric unless you intend to run
'raw' SQL queries against the database and want to do numeric
comparisons.

For each list valued search key, we need another table which (no
surprise) is a classic link table. The name is constructed by
concatenating the collection name and key name, with a '_' in between.

If 'friends' were a search key in the Person collection. the link
table would be

 create table Person_friends (
   oid bigint unsigned not null,  --- foreign key pointing to _AutoDB
   friends bigint unsigned        --- foreign key pointing to _AutoDB
                                  --- (will be a Person)
   );

A small detail: since the whole purpose of these tables is to enable
querying, indexes are created for each column by default (indexes can
be turned off by specifying index=>0 to the AutoDB constructor).

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

=head3 Data::Dumper details

We rely on "freezer" and "toaster" methods to convert references to
persistent objects into oids when objects are stored, and convert oids
back to references when objects are fetched.  The native support for
"freezer" and "toaster" methods in L<Data::Dumper> (as of version
2.125) falls short of our needs in two respects:

=over 2

=item 1. Data::Dumper requires that the "freezer" method modify the
object being dumped, rather than letting the method return a modified
copy of the object.

=item 2. If any class has a "toaster" method, Data::Dumper assumes all
classes do and emits a call to the method even if the object in
question can't do it.

We modified Data::Dumper to fix these problems. To avoid any confusion
with the official version of the code, we renamed the modified version
Class::AutoDB::Dumper and include it in our code tree.

Data::Dumper provides both pure Perl and much faster C (.xs)
implementations.  We modified both implementations.

B<Caveat>: The build process automatically compiles the C
implementation I<if your system has a C compiler>. We see a few
compiler warnings in this process. These seem benign and can be
ignored. The Data::Dumper docs claim that the code will fall back to
the pure Perl implementation if the C version is not available.  We
haven't checked this claim.

=back

=head1 METHODS AND FUNCTIONS

=head2 'new' and manage database connections

=head3 new

 Title   : new
 Usage   : my $autodb=new Class::AutoDB database=>'test'
           -- OR --
           my $autodb=new Class::AutoDB database=>'test',host=>'localhost',
                                        user=>'fake',password=>'fake'
           -- OR --
           my $autodb=new Class::AutoDB database=>'test',create=>1
           -- OR --
           my $autodb=new Class::AutoDB database=>'test',drop=>1
           -- OR --
           my $autodb=new Class::AutoDB database=>'test',alter=>1
           -- OR --
           my $autodb=new Class::AutoDB database=>'test',read_only_schema=>1
           -- OR --
           many other combinations
 Function: Connect to database, control schema modification
 Returns : New Class::AutoDB object
 Args    : Connection parameters (MySQL only, at present). All except 'database'
           are optional

             database Database name. No default
             host     Database host (or server). Defaults to localhost
             server   Synonym for 'host'
             user     Database username. Defaults to current user, more 
                      precisely, USER environment variable
             password Database user's password. Defaults to no password
             pass     Synonym for 'password'
             dbd      Name of DBD driver. Defaults to 'mysql' which is only one
                      currently supported
             dsn      DSN (data source) string in the format supported by DBD
                      driver. For MySQL, the format is 
                      "dbi:mysql:database_name[:other information]". See DBI and
                      DBD::mysql.  Usually computed from other parameters
            socket    MySQL socket. Usually not defined
            sock      Synonym for 'socket'
            port      Database server port. Usually not defined
            timeout   MySQL inactive session timeout in seconds. The system 
                      default (8 hours unless changed by your database admin) is
                      usually fine
            dbh       Connected database handle returned by DBI::connect.
                      'new' usually gets this by calling DBI::connect itself
           The connection parameters provided are ones we find useful in our 
           work. Many more are possible. If you need other parameters, you can 
           construct a DSN or open a DBH in your code and pass it in.

           Schema modification parameters
           Control schema changes carried out automatically by 'new'. Illegal to
           set more than one to true. When all left unspecified or undef, system
           adopts this default:
           1) if database does not exist, it is created;  
           2) if database exists, but some needed collections do not exist, they
              are created;
           3) existing collections are not altered.

             create   Controls whether the database may be created.
                      undef              see default described above
                      true               forces database creation
                      defined but false  database not created even if it does 
                                         not exist
             alter    Controls whether schema may be altered
                      undef              see default described above
                      true               schema changes allowed. collections and
                                         search keys added as needed
                      defined but false  schema alterations not allowed
             drop     Controls whether database dropped
                      true               database dropped
                      any false value    database not dropped 
             read_only_schema 
                      Single option to turn off 'create', 'alter', 'drop'
                      true               no schema changes allowed
                      any false value    schema changes allowed under control of
                                         other parameters

=head3 AutoDB attributes

You can access many parameters to 'new' using method notation.  Most
of these should be set only by 'new', but this is not
enforced. Attributes related to the database connection, eg,
'database', 'host', etc., are computed from the DBH or retrieved from
the database server if the DBH is set.

To get the value of attribute xxx, just say

  $xxx=$autodb->xxx;

To set an attribute, say

  $autodb->xxx($new_value);

The available attributes are

=over 2

=item * database Database name

=item * host     Database host (or server)

=item * server   Synonym for 'host'

=item * user     Database username

=item * password Database user's password

=item * pass     Synonym for 'password'

=item * dbd      Name of DBD driver. Must be 'mysql' at present
 
=item * dsn      DSN (data source) string in the format supported by DBD driver

=item * socket   MySQL socket. Usually not defined

=item * sock     Synonym for 'socket'

=item * port     Database server port. Usually not defined

=item * dbh      Connected database handle returned by DBI::connect

=item * timeout  MySQL inactive session timeout in seconds. The system default
                 (8 hours (28800 seconds) unless changed by your database admin)
                 is usually fine. The value returned is retrieved from the 
                 database server and can change out from under you. If the
                 server decides the timeout is too small, it resets it to the 
                 system default. 
 
=item * read_only_schema Single option to turn off 'create', 'alter', 'drop'
 
=back

Note that the 'create', 'alter', and 'drop' parameters cannot be
accessed in this way, because the methods that performed the indicated
actions have the same names.  Sorry.

=head3 renew

 Title   : renew
 Usage   : $autodb->renew(read_only_schema=>1)
 Function: Reinitialize $autodb object
 Returns : same Class::AutoDB object
 Args    : same as 'new'
 Notes   : Uses parameters set in 'new' unless changed by args

Reinitializes the AutoDB object, disconnects from the database, and
reconnects. This method is rarely needed; usually you want
L<reconnect> .

=head3 connect

 Title   : connect
 Usage   : $autodb->connect
           -- OR --
           $autodb->connect(database=>'test')
 Function: Connect to database. Does nothing if already connected
 Returns : database handle (DBH) if successful, else undef
 Args    : same as 'new'
 Notes   : Uses connections parameters set in 'new' unless changed by args

'new' calls this method to establish the database connection. Since,
at present, 'new' will fail if it is unable to make the connection,
there is little reason to call 'connect' later. You should use
L<reconnect> to change the connection.

=head3 disconnect

 Title   : disconnect
 Usage   : $autodb->disconnect
 Function: Disconnect from database
 Returns : undef
 Args    : none

Users rarely need to run this, because connections go away
automatically when your program ends.

=head3 reconnect

 Title   : reconnect
 Usage   : $autodb->reconnect
           -- OR --
           $autodb->reconnect(database=>'test')
 Function: Disconnect from database and then connect
 Returns : database handle (DBH) if successful, else undef
 Args    : same as 'new'
 Notes   : Uses connections parameters set in 'new' unless changed by args

This is the method to use if you want to change connection parameters,
such as the database or user. It's okay to use this even if you have
already done a 'disconnect'.

=head3 is_connected

 Title   : is_connected
 Usage   : $autodb->is_connected
 Function: Tell if there is a usuable database connection
 Returns : undef
 Args    : none

This really just sees if the DBH is set. Use L<ping> to test if the connection is live.

=head3 ping

 Title   : ping
 Usage   : $autodb->ping
 Function: Tell if the database connection is live
 Returns : undef
 Args    : none

We recommend using this as a last resort, because of potential
performance problems.  In most cases, L<is_connected> is adequate.
Actually, in most cases, you can just assume that there is a
connection, because 'new' will fail if it cannot establish the
connection, and the underlying DBI software will reconnect
automatically if the connection breaks.

=head2 Queries

The methods described here operate on Class::AutoDB objects.  See
L<"METHODS AND FUNCTIONS - Cursors"> for related methods operating on
Class::AutoDB::Cursor objects.

=head3 get

 Title   : get
 Usage   : my @males=$autodb->get(collection=>'Person',name=>'Joe',sex=>'M')
           -- OR --
           my $males=$autodb->get(collection=>'Person',name=>'Joe',sex=>'M')
           -- OR --
           my @males=$autodb->get(collection=>'Person',
                                  query=>{name=>'Joe',sex=>'M'})
           -- OR --
           my $males=$autodb->get(collection=>'Person',
                                  query=>{name=>'Joe',sex=>'M'})
 Function: Execute query and return results
 Returns : list or ARRAY of objects satisfying query
 Args    : collection Name of collection being queried
           query      search_key=>value pairs. Each search key must be defined
                      for collection. Each value must be single value of correct
                      type for search key. For all types except 'object' or 
                      'list(object)', value must be simple scalar (string or 
                      integer). For 'object' or 'list(object)', value must be
                      persistent object
           other args interpreted as search_key=>value pairs

search_key=>value pairs are ANDed. For list types, the query is true if
any element on list has the value. If a collection has a search key named
'collection', you must use an explicit 'query' arg to include it in a query.

=head3 find

 Title   : find
 Usage   : my $cursor=$autodb->find(collection=>'Person',name=>'Joe',sex=>'M')
           -- OR --
           my $cursor=$autodb->find(collection=>'Person',
                                    query=>{name=>'Joe',sex=>'M'})
 Function: Execute query. 
 Returns : Class::AutoDB::Cursor object which can be used to retrieve results
 Args    : same as 'get'
 Notes   : same as 'get'

=head3 count

 Title   : count
 Usage   : my $count=$autodb->count(collection=>'Person',name=>'Joe',sex=>'M')
           -- OR --
           my $count=$autodb->count(collection=>'Person',
                                    query=>{name=>'Joe',sex=>'M'})
 Function: Count number of objects satisfying query
 Returns : number
 Args    : same as 'get'
 Notes   : same as 'get'

=head3 oid

 Title   : oid
 Usage   : my $oid=$autodb->oid($object)
 Function: Access object's oid (immutable object identifier)
 Returns : oid as number, NOT Class::AutoDB::Oid object. undef if argument not
           persistent
 Args    : persistent object or Class::AutoDB::Oid object

=head2 Cursors

The methods described here operate on Class::AutoDB::Cursor objects
returned by L<"find">.  See L<"METHODS AND FUNCTIONS - Queries"> for
related methods operating on Class::AutoDB objects.

=head3 get

 Title   : get
 Usage   : my @males=$cursor->get
           -- OR --
           my $males=$cursor->get
 Function: Retrieve results of query associated with cursor
 Returns : list or ARRAY of objects satisfying query
 Args    : none

It is possible to mix 'get' and 'get_next' operations. If some
'get_next' operations have been run on cursor, 'get' retrieves
remaining objects

=head3 get_next

 Title   : get_next
 Usage   : my $object=$cursor->get_next
 Function: Retrieve next result for cursor or undef if there are no more
 Returns : object satisfying query or undef
 Args    : none
 Notes   : Allows simple while loops to iterate over results as in SYNOPSIS

=head3 count

 Title   : count
 Usage   : my $count=$cursor->count
 Function: Count number of objects satisfying query associated with cursor
 Returns : number
 Args    : none

=head3 reset

 Title   : reset
 Usage   : $cursor->reset
 Function: Re-execute query associated with cursor.
 Returns : nothing
 Args    : none
 Notes   : Subsequent 'get' or 'get_next' operation will start at beginning 

=head2 Updates

=head3 put

 Title   : put
 Usage   : $autodb->put(@objects)
 Function: Store one or more objects in database
 Returns : nothing
 Args    : list of persistent objects or Oids

The difference between 'put' and 'put_objects' is that when called
with no objects, 'put' does nothing, while 'put_objects' stores all
persistent objects

=head3 put_objects

 Title   : put_objects
 Usage   : $autodb->put_objects
           -- OR --
           $autodb->put_objects(@objects)
 Function: Store all persistent objects (first form) or list of persistent 
           objects (second form)
 Returns : nothing
 Args    : list of persistent objects or Oids

The difference between 'put' and 'put_objects' is that when called
with no objects, 'put' does nothing, while 'put_objects' stores all
persistent objects

=head2 Manage database schema 

=head3 exists

 Title   : exists
 Usage   : my $bool=$autodb->exists
 Function: Test whether AutoDB database exists
 Returns : boolean
 Args    : none

=head3 register

 Title   : register
 Usage   : $autodb->register(class=>'Person',collection=>'Person', 
                             keys=>qq(name string, sex string, id integer),
                             transients=>qq(name_prefix sex_word))
 Function: Register collection with the system
 Returns : nothing
 Args    : class      whitespace- or comma-separated string of class names, or
                      ARRAY of class names (optional)
           other args any valid form of %AUTODB

When you 'register' new collections or add search keys to existing
ones, the system creates or alters database tables as needed to
implement your changes.  These effects are persistent, of course.

When you 'register' new associations between classes and collections,
these changes are in effect for the current session only. This makes
it possible to dynamically change the collections into which new
objects are put.

=head3 create

 Title   : create
 Usage   : $autodb->create
 Function: Create AutoDB database
 Returns : nothing useful
 Args    : none

The system drops the existing AutoDB database, if any, and then
creates the new one. Dropping the old database drops the _AutoDB table
and all tables used to implement the collections that exist in the
saved registry. Creating the new database creates the_AutoDB table and
all tables needed to implement the collections registered in the
current, in-memory registry.

The 'create' option to 'new' runs this method.

=head3 alter

 Title   : alter
 Usage   : $autodb->alter
 Function: Alter AutoDB database to reflect differences between current,
           in-memory registry and saved registry
 Returns : nothing useful
 Args    : none

The only alterations that are allowed are expansions. New collections
can be created and new search keys can be added to existing
collections. 

Users rarely need to use this method, because the system handles
alterations automatically.

=head3 drop

 Title   : drop
 Usage   : $autodb->drop
 Function: Drop AutoDB database
 Returns : nothing useful
 Args    : none

The system drops the existing AutoDB database, if any. This drops the
_AutoDB table and all tables used to implement the collections that
exist in the saved registry.

The 'drop' option to 'new' runs this method.

=head2 Persistent objects and Oids 

When you declare a class to be persistent, we arrange for it to
inherit from Class::AutoDB::Object by modifying its @ISA array. This
has the effect of polluting your class's namespace with inherited
methods.  It was a bad idea.  Sorry.  We plan to change this in a
future release (currently planned for 1.30; see L<DEVELOPMENT
ROADMAP>).

Two of the inherited methods are commonly used. These can be invoked
on a persistent object or a Class::AutoDB::Oid object. It's usually
okay to override these methods.  Our code never calls them, so
overriding them won't break any Class:AutoDB mechanisms.

B<Caveat>: Class::AutoDB::Oid also defines these methods. If you
override these methods, your version will B<not> be invoked on a
Class::AutoDB::Oid object.  If this is a problem, you should make sure
your objects are thawed before invoking the methods.

=head3 put

 Title   : put
 Usage   : $object->put
 Function: Store object in database
 Returns : nothing
 Args    : none
 Notes   : Deprecated.  Should use $autodb->put($object)

=head3 oid

 Title   : oid
 Usage   : my $oid=$object->oid
 Function: Access object's oid (immutable object identifier)
 Returns : oid as number, NOT Class::AutoDB::Oid object
 Args    : none
 Notes   : Deprecated.  Should use $autodb->oid($object)

=head1 SEE ALSO

We rely on L<DBI> and its MySQL driver, L<DBD::mysql>, for access to
the underlying database.  See L<DBI> for information on database
handles (DBHs) and L<DBD::mysql>, for the format of data source name
(DSN) strings.

This class works closely with L<Class::AutoClass> whose 'declare'
function sets up persistent classes using the value of %AUTODB.

Many CPAN modules provide capabilities similar to those provided
here. These include L<Alzabo>, L<Class::DBI>, L<DBIx::Class>,
L<DBIx::RecordSet>, L<DBM::Deep>, L<Fey::ORM>, L<KiokuDB>, L<OOPS>,
L<ORM>, L<Pixie>, L<SPOPS>, and L<Tangram>.

=head1 AUTHOR

Nat Goodman, C<< <natg at shore.net> >>

=head1 BUGS AND CAVEATS

Please report any bugs or feature requests to C<bug-class-autodb at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-AutoDB>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head2 Known Bugs and Caveats

=over 2

=item 1. This module is old

We use it, and it works well for our purposes, but it's showing its age.

=item 2. The current version only works with MySQL

The first step of the installation process, 'perl Build.PL', makes
sure that MySQL is available and that the person doing the
installation has sufficient privileges to run the test suite. If this
check fails, Build.PL does not generate the Build script and exits
with a 0 return code. This is the idiom recommended for automated CPAN
testing but may be too severe for normal installs.

=item 3. One AutoDB at a time

You can only have one active AutoDB object at a time.  Grievous errors
will occur if you run 'new' a second time on a different database.

=item 4. No delete operation

This is on our to-do list!  The issue that's held this up is that
deletion is not a Perl concept -- you never have to delete a Perl
object -- and it's not obvious how to make it intuitive for
applications to handle deleted persistent objects.  In our running
example, suppose you delete a Person Joe who's on Mary's friends list.
When processing Mary's friends, what should happen to Joe?  Should we
silently delete him from the list?  Or should we leave him on the list
but return undef when your program accesses him?  Or something else?

=item 5. No transactions

This is also on our to-do list, but further down, as we have no urgent
need for transactions in our application.

=item 6. Type mismatches

If data of the wrong type is stored in a search key, data conversion
occurs as described in L<Type mismatches>.

=item 7. Class attributes not stored or retrieved

Class attributes (as that term is used in L<Class::AutoClass>) are not
stored in the AutoDB database and are not set when objects are fetched
or classes 'used'. This is related to the simple way class attributes
are handled in Class::AutoClass.

=item 8. Uneven error checking

The software does not consistently check for user errors. If you make
a mistake and pass in bad data. the software sometimes responds with
an intelligible error message but often does not.  All too often, the
mistake winds its way into the guts of the software which ultimately
dies with an inscrutable message.
 
=back

=head1 DEVELOPMENT ROADMAP

Subject to change, of course.  You will notice, I'm sure, that no dates are attached to releases.

=begin html

<h2>1.20 database operations</h2>
<h3>'del' operation - a bit messy since object deletion is not a Perl concept!</h3>
<ul>
<li>messy since object deletion is not a Perl concept!</li>
<li>similar issues aries with weak references. I think Perl causes deref of lost reference to return undef</li>
<ul>
<li>this has to complicate the application (see notes below).  but is there a better choice??</li>
<li>See Hash::NoRef for weak cache -- not sure if this comment is still relevant</li>
</ul>
<li>Database part is easy: delete object from object table and all collections (should consult saved registry for full list of collections that may contain the object)</li>
<li>Object cache is a little tricky: if the oid is present in the cache as an Object, deflate it to an Oid; if it's present as an Oid, do nothing.</li>
<li>Hard part is that other in-memory or in-database objects may contain references to the deleted object.</li>
<ul>
<li>Serialize::fetch handles this case fine - it returns undef</li>
<li>Have to check everywhere in our code that does 'fetch' or 'really_fetch' to make sure undef is handled.</li>
<li>One place is in Cursor::get - obvious action is to skip undefs</li>
<li>Harder case is Oid::AUTOLOAD - the simplest action would be to return undef to the application, but this is misleading: the app said something like $obj-&gt;xxx expecting to get the 'xxx' attribute; giving him undef suggests that 'xxx' is undef, not that $obj is deleted!  Perhaps we should throw an exception, but can the app catch it??</li>
</ul>
</ul>
<h3>Easy database things (raw SQL in 'find' and other improvements to 'find' queries)</h3>
<ul>
<li>Allow raw SQL</li>
<ul>
<li>Extremely easy - the code is already set up to do it.  See Cursor::select_sql and Cursor::count_sql</li>
</ul>
<li>Allow arbitrary MySQL types</li>
<ul>
<li>Should be done in conjunction with cleaning up the type stuff in Table</li>
</ul>
<li>AND'ing new query onto Cursor</li>
<li>let empty query retrieve all objects.  ie $autodb-&gt;get</li>
<li>DBI::quote seems to be quoting numbers - I wonder if this is correct</li>
</ul>
<h3>consider new serialization schemes</h3>
<ul>
<li>want to handle ties. at least, Hash::AutoHash and friends</li>
<li>Storable may be viable</li>
<ul>
<li>looks like new 'attach' hook gives us what we need. another plus is that it handles ties.</li>
<li>a plus is that Storable handled ties</li>
<li>problem is that output is not human readable</li>
</ul>
<li>do a combination of Storable for the heavy lift and DD to produce readable form</li>
</ul>
<h3>Table</h3>
<ul>
<li>Refactor TYPES - currently duplicated in several modules - a real landmine waiting to go off!</li>
<li>Provide utility methods for working with types</li>
<li>Might be better to let Table do the database ops itself rather than just generating SQL - doesn't matter much now, but may make statement handles easier to manage</li>
</ul>
<h3>add 'configure' to Build process</h3>
<h2>1.30 namespace issues</h2>
<h3>clean up namespace imposed on user-objects (maybe in AutoClass, too)</h3>
<ul>
<li>we currently splice Class::AutoDB::Object into user-class's @ISA.  Object, in turn, inherits from Serialize.  this is a bad idea that puts a lot of methods in user namespace</li>
<ul>
<li>the code depends on this, among other things, to know whether a class is persistent. the code also uses this to gain access to methods like 'fetch' and 'thaw'</li>
<li>we want to stop this, which will, of course, require finding another way to tell whether a class is persistent and to invoke 'fetch', 'thaw', etc.</li>
</ul>
<li>it would be nice to continue providing convenience methods in user namespace: 'put', 'oid', and maybe 'autodb'.</li>
<ul>
<li>it must be okay for user to override these, which means our code must never call them. I think this is already the case</li>
<li>the hard problem is what to do when invoked on Oids. </li>
<li>presently, the Oid versions of these are hardcoded. to do it right, Oid code has to check whether user has overridden the method; if so, has to fetch and re-dispatch to user object</li>
<li>instead of, or in addition to, 'autodb' method on user-objects, have AutoDB provide this as an exported function.</li>
<ul>
<li>think though implications when we allow multiple active AutoDB objects</li>
</ul>
</ul>
</ul>
<h3>AutoDB methods to list objects (or maybe oids??) -- this is a 'maybe' item</h3>
<ul>
<li>mem_objects -- all persistent objects in memory -- these are the ones that will be put by put_objects</li>
<li>db_objects -- objects in database -- gets 'em all as Oids</li>
<li>all_objects -- union of mem+db</li>
<li>mem_only_objects (or maybe new_objects) -- objects in memory but not yet in db</li>
<li>db_only_objects</li>
<li>del_objects -- someday -- deleted objects -- here is where 'oids' makes more sense than 'objects'</li>
</ul>
<h2>1.40 improved put/get; performance improvements</h2>
<h3>New thoughts on 'put' -- batch 'put' is super performance win</h3>
<ul>
<li>Improve efficiency of put_objects method and add ability to feed in list of objects. Should really be done as part of put-policy</li>
<ul>
<li>By default, $ob-&gt;put doesn't write the object immediately, but rather puts it on a queue for later writing</li>
<li>$autodb-&gt;put does actual writes. Called automatically by $autodb-&gt;close and maybe destructor if we can get this to work.</li>
<li>In the full scheme of things, 'put' can specify queue so that objects can be written at different times. This could grow into a limited transaction capability.</li>
<li>$obj-&gt;put could also specify whether current state of object should be written, or state as it exists when $autodb-&gt;put is called. The latter option is really another way of saying, “$obj is dirty” and is a backdoor way of approximating auto-put.</li>
<li>For performance, $autodb-&gt;put presumably will sort database operations by table and do updates in batches</li>
<li>Ideally want to group updates by table and do each table in bulk.</li>
<li>This is going to be a pain - have to refactor code to collect SQL bits and pieces and put them together at the top. Will affect a lot of tests…</li>
<li>Here's a plausible design.</li>
<ul>
<li>Each table has methods to</li>
<li>also need to collect list of tables with pending updates. This could be attached to the autodb</li>
</ul>
<li>Updates to _AutoDB.</li>
<ul>
<li>Class::AutoDB::Object:::put calls Class::AutoDB::Serialize::store on each object</li>
</ul>
<li>Updates to Collections</li>
<ul>
<li>Class::AutoDB::Object:::put calls Collection::put on each object which calls BaseTable::put and ListTable::put</li>
</ul>
</ul>
<li>'dirty bit' put policy</li>
<ul>
<li>May be better to think of this as 'deferred put'.</li>
<li>When code decides that object is dirty, puts it on a list of objects to be 'put'</li>
<li>Later, perhaps during $autodb-&gt;put, the actual database updates occur</li>
</ul>
<li>Look at renaming put_objects to 'put'. This will simply work.  Just need synonym and add to tests</li>
<li>re-get (or maybe refresh) to get current value of object from database</li>
</ul>
<h3>Performance improvements for 'get'</h3>
<ul>
<li>may be useful to let object provide list of "related objects" and get them all at once</li>
</ul>
<h3>Use statement handles in Serialize and Table to improve performance</h3>
<h3>design concurrency/transaction scheme -- will be implemented later</h3>
<h2>1.50 better collections; class extents, etc.</h2>
<h3>class attributes </h3>
<ul>
<li>not set when class 'used' in the course of fetching objects. see discussion under AutoClass</li>
<li>AutoDB does not store class attributes</li>
<li>related to simple way class attributes handled in AutoClass</li>
</ul>
<h3>Test subclass w/o collection, i.e., transients only</h3>
<h3>Class extents</h3>
<ul>
<li>implement as more or less standard list table, e.g. _AutoDB_classes(class,oid)</li>
<li>Specify via a flag in &#37AUTODB</li>
<li>subclasses have to insert in parent extents</li>
</ul>
<h2>1.60 multiple AutoDBs</h2>
<h3>Allow program to have multiple AutoDB objects, connected to different databases</h3>
<h3>Objects fetched from a given database are, by default, put back there</h3>
<h3>Probably also possible for 'put' to specify which database gets the object</h3>
<h3>Big problem is schema registration. Presently, schemas are auto- registered in default database.  With new scheme, how does program conveniently control this?</h3>
<h2>1.70 oid management</h2>
<h3>Current scheme -- generate unique id in Perl, use MySQL 'replace' to insert or update.  (Note: MySQL's 'insert… on duplicate key update' is a better choice, but it's only available from 4.1)  Problems:</h3>
<ul>
<li>The database will be seriously corrupted if a new oid isn't unique!!</li>
<li>'replace' isn't available in Postgres; will either need extra 'select' or stored procedure -- is this still true?</li>
<li>'replace' is available in SQLite</li>
</ul>
<h3>Alternative - get sequence number from database</h3>
<h3>Another goal: ensure uniqueness of oids constructed on different machines, so databases can be safely merged...</h3>
<h3>Option 1 - do it when object constructed</h3>
<ul>
<li>Problem - extra trip to database</li>
<li>Benefit - every update to object (even first) is a database 'update' - works for MySQL and Postgres</li>
</ul>
<h3>Option 2 - do it when object stored</h3>
<ul>
<li>Benefit - avoids extra trip to database</li>
<li>Problem - self-referential objects are complicated.  If freeze code encounters the same object twice during serialization, there won't be an oid yet.  The obvious recursion (if object doesn't have oid, then store it) leads to infinite loop.  Probably need to maintain a hash of 'in-progress' objects; if freeze encounters an in-progress object, it has to do a dummy insert just to get the oid.</li>
</ul>
<h2>1.80 persistent big HASH and ARRAY</h2>
<h3>persistent HASH</h3>
<h3>persistent ARRAY --  harder because of shifts &amp; splices!!</h3>
<ul>
<li>(see also implementation of BerkeleyDB recno files)</li>
<li>The obvious implementation is to give ARRAY elements an 'array_index' key, starting at 0.</li>
<li>So long as you just do pushes and pops, the array will grow and shrink on high end, and the mapping from Perl array index to database array index is trivial</li>
<li>But, when a shift is done, the element at the low end disappears and now the 0th Perl element has database index 1</li>
<li>So, we need a translation mechanism that maps Perl index values into database index values</li>
<li>In general, splice can introduce 'holes' and 'bumps' into the mapping: e.g., if you delete 10 elements from the middle of the ARRAY, the bordering Perl index values will differ by 10 in the database; or if you add 10 elements to the middle of the ARRAY, the database indexes assigned to these guys will be discontinuous from their neighbors</li>
<li>Blech…</li>
<li>Possible implementation: translation table is a list of &lt;count, database index&gt; pairs.  Meaning is that the first/next count elements have database indexes index, index+1,…, index+count-1</li>
<li>In usual case (no general splices), table has one entry</li>
</ul>
<h3>make sure design will work with concurrency</h3>
<h2>2.00 port to SQLite or other DBMS</h2>
<h2>2.10 concurrency/transactions</h2>

=end html

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Class::AutoClass


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-AutoClass>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Class-AutoClass>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Class-AutoClass>

=item * Search CPAN

L<http://search.cpan.org/dist/Class-AutoClass/>

=back


=head1 ACKNOWLEDGEMENTS

Chris Cavnor maintained the CPAN version of the module for several
years after its initial release.

=head1 COPYRIGHT & LICENSE

Copyright 2003, 2009 Nat Goodman, Institute for Systems Biology
(ISB). All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Class::AutoDB
