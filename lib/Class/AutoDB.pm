package Class::AutoDB;
our $VERSION = '0.02';
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use DBI;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Registry;
use Class::AutoDB::RegistryDiff;
use Class::AutoDB::Cursor;
use Data::Dumper;
use Scalar::Util ();
@ISA = qw(Class::AutoClass);

use Class::AutoDB::Lookup;
my $lookup = new Class::AutoDB::Lookup;

BEGIN {
  @AUTO_ATTRIBUTES=qw(dsn dbh dbd database host user password 
		      read_only read_only_schema
		      object_table registry
		      session cursors diff
		      _needs_disconnect _db_cursor);
  @OTHER_ATTRIBUTES=qw(server=>'host');
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);
}
use vars qw($AUTO_REGISTRY);
$AUTO_REGISTRY=new Class::AutoDB::Registry;

sub auto_register {
  my($class,@args)=@_;
  $class->connect(@args) unless $class->is_connected;
  $AUTO_REGISTRY = $class->registry || new Class::AutoDB::Registry;
  $AUTO_REGISTRY->register(@args);
}

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $self->registry || $self->registry($AUTO_REGISTRY);
  $self->connect(%$args);
  return unless $self->is_connected;
  my $find=$args->find;
  unless ($find) {
    return $self->_manage_registry($args);
  } else {
    return $self->_manage_query($args,$find);
  }
}
sub _manage_query {
  my($self,$args,$query)=@_;
  if($query) {
    $self->find($query);
  }
}

sub _manage_registry {
  my($self,$args)=@_;
  # this should return a session-oriented object
  $self->session(1);
  # grab schema modification parameters
  my $read_only_schema=$self->read_only_schema || $self->read_only;
  my $drop=$args->drop;
  my $create=$args->create;
  my $alter=$args->alter;
  my $count=($create>0)+($alter>0)+($drop>0);
  $self->throw("It is illegal to set more than one of -create, -alter, -drop") if $count>1;
  $self->throw("Schema changes not allowed by -read_only or -read_only_schema setting") if $count && $read_only_schema;
  
  # get saved registry and merge with in-memory registry
  my $in_memory=$self->registry;
  my $saved=new Class::AutoDB::Registry(-autodb=>$self,-object_table=>$self->object_table,-get=>1);
  my $diff=new Class::AutoDB::RegistryDiff(-baseline=>$saved,-other=>$in_memory);
  if (!$diff->is_sub) {		# in-memory schema adds something to saved schema
    $self->throw("In-memory and saved registries are inconsistent") unless $diff->is_consistent;
    $self->throw("In-memory registry adds to saved registry, but schema changes are not allowed by -read_only or -read_only_schema setting") if $read_only_schema;
    unless ($count) {
      # if no options are set can only make default changes
      if ($saved->exists) {	
	$self->throw("In-memory registry adds to saved registry, but schema alteration prevented by -alter=>0") if $alter eq 0;
	# alter-if--exists case -- can only add collections
	$self->throw("Some collections are expanded in-memory relative to saved registry.  Must set -alter=>1 to change saved registry") if $diff->has_expanded;
      } else {
	$self->throw("Schema does not exist, but schema creation prevented by -create=>0") if $create eq 00;
      }
    }
    $saved->merge($diff);
  }
  $self->registry($saved);
  $self->diff($diff);
  # Now do specified schema operations
  $self->drop, return if $drop;
  $self->create, return if $create;
  $self->alter, return if $alter;
  
  # Finally, do default schema operations if required
  if (!$diff->is_sub) { # in-memory schema adds something to saved schema
    $self->create, return if !$saved->exists;
    $self->alter, return if $saved->exists;
  }
  return $self;
}
sub connect {
  my($self,@args)=@_;
  my $args=new Class::AutoClass::Args(@args);
  $self->Class::AutoClass::set_attributes([qw(dbh dsn dbd host server user password database)],$args);
  $self->_connect;
}
sub _connect {
  my($self)=@_;
  return $self->dbh if $self->dbh;		# if dbh set, then already connected
  my $dbd=lc($self->dbd)||'mysql';
  $self->throw("-dbd must be 'mysql' at present") if $dbd && $dbd ne 'mysql';
  my $dsn=$self->dsn;
  if ($dsn) {			# parse off the dbd, database, host elements
    $dsn = "DBI:$dsn" unless $dsn=~ /^dbi/i;
  } else {
    my $database=$self->database;
    my $host=$self->host || 'localhost';
    #(warn("connect requires 'database' and 'host' args") and return undef) unless ($database && $host);
    $dsn="DBI:$dbd:database=$database;host=$host";
  }
  
  # Try to establish connection with data source.
  my $user = ($self->user || $self->user('root'));
  my $dbh = DBI->connect($dsn,$user,$self->password,
			 {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, Warn=>0,});
  $self->dsn($dsn);
  $self->dbh($dbh);
  $self->_needs_disconnect(1);
  $self->throw("DBI::connect failed for dsn=$dsn, user=$user: ".DBI->errstr) unless $dbh;
  return $dbh;
}

sub create {
  my($self)=@_;
  my $registry=$self->registry;
  $registry->create($self->registry->collections);
}
sub drop {
  my($self)=shift;
  my $registry=$self->registry;
  $registry->drop(@_);
  $self->registry(new Class::AutoDB::Registry(-autodb=>$self)); # reset registry
}
sub alter {
  my($self)=@_;
  my $registry=$self->registry;
  my $diff=$self->diff;
  return unless $diff;		# can't alter without a diff
  $registry->put;
  my $new_collections=$diff->new_collections;
  $registry->create(@$new_collections) if @$new_collections;
  my $expanded_diffs=$diff->expanded_diffs;
  $registry->alter(@$expanded_diffs) if @$expanded_diffs;
  $self->diff(undef);		# registries are now in synch
}

sub exists {
  my $self = shift;
  # use AutoDB's dsn entry if it is more complete than registry's copy
    unless( $self->registry->autodb->dsn =~ /database=(\w+)\:/ ){
      unless($self->dsn =~ /database=(\w+)[\:\;]/){
		warn("you have not specified a database in your connection parameters");
      } else {
      	  #dbh based on incomplete dsn
          $self->registry->autodb->{dbh} = $self->dbh;
      }
  }
  $self->registry->exists ? 1 : 0;
}

# receives a session-oriented Registry object from _manage_query
sub find {
  my($self,@query)=@_;
  my %normalized = _flatten(@query);
  my $args = new Class::AutoClass::Args(%normalized);
  $self->exists || $self->throw("registry was not found in the database");
  if(defined $args->collection) {
    # nothing to do 
  }
  elsif($query[0] =~ /^select/i) {
    $self->throw("free-form query not yet supported");
    return;	
  }
  else {
  	$self->throw("query must either contain a collection argument or be a free-form SELECT statement");
  	return;
  }
  
  # need to return a cursor obj
  my $collections = $self->registry->get;
  my $collection_to_find = $args->collection;
  my ($found, $cursor);
  foreach my $collection(@$collections){
   next unless $collection->name eq $collection_to_find;
   my $keys = $args->getall_args;
   # TODO: still need to pass the dbh?
   $cursor = Class::AutoDB::Cursor->new(-collection=>$collection, -search=>$keys, -dbh=>$self->dbh);
   $found = 1;
  }
  warn("collection: $collection_to_find was not found in the database") unless $found;
  return $cursor;
}

# store the nvp's in the database
sub store{
  my ($self,$persistable,$persistable_name)=@_;
  next unless values %$persistable;
  my $object_table = $self->registry->object_table;
  my $registry = $self->registry;
  my $dbh=$self->dbh;
  my $lookup_table = $registry->object_table;
  my $object_id = $persistable->{__object_id}; # only present if collection pulled from database
  my $class_table = ref($persistable);
  my (@collKeys, @collValues, %list, $this_list);
  
  # give UID (__object_id will override if present)
  $persistable->{UID} = _getUID() unless ( $persistable->{UID} || $persistable->{__object_id} );
  # only interested in subset of keys in the persistable objects
  while(my($k,$v) = each %{$registry->name2coll->{$persistable_name}->_keys}) {      
    # handle lists
    if($v =~ /list\(\w+\)/){
      next unless $persistable->{$k};
      my $listname = "$persistable_name"."_$k";
      $list{$listname} = $persistable->{$k};
      # consider list to be handled
      delete $persistable->{$k};
    }
    push @collKeys, $k if exists $persistable->{$k};
    push @collValues, $v if exists $persistable->{$k};
  }  
  
  my ($aggCollKeys) = join ",", @collKeys;
  my ($aggCollValues) = join ",", map { DBI::neat($_) } @collValues;

  # prepare insert string
  my ($aggInsertableValues) = join ",", map { DBI::neat($_) } values %$persistable;
  # prepare update string
  my $aggUpdatableValues;
  
  # filter out special keys (begin with "__")
  my $arg_cnt = (scalar keys %$persistable);
  while(my($k,$v) = each %$persistable){
    $arg_cnt--;
    next if $k =~ /^__/; # we don't store __special keys
    next if $k eq 'UID'; # never update object's id
    $aggUpdatableValues .= "$k\=" . DBI::neat($v);
    $aggUpdatableValues .= ',' if $arg_cnt;
  }

  if($self->exists) {
    # INSERT
    unless($object_id) {
      my $insert_statement = qq/insert into $class_table(object,$aggCollKeys) values($aggInsertableValues)/;
      $dbh->do($insert_statement);
      # UPDATE
      } else {
      	  my $update_statement = qq/update $class_table set $aggUpdatableValues where object=$object_id/;
       	  eval{ $dbh->do($update_statement) } 
      }
      # handle lists
      if(scalar keys %list) {
       my($listname,$frozen_value) = %list;
       my $id = $persistable->{UID};
       my ($sth, $dirty);
       my $dumper=new Data::Dumper([undef],['thaw'])->Purity(1)->Indent(0);
       my $freeze=$dumper->Values([$frozen_value])->Dump;
       $list{$listname} = _freeze($freeze);
       $lookup->recall($frozen_value) ? $dirty=1 : $lookup->remember($frozen_value);
       unless($object_id) {
         # INSERT
	     eval { $sth = $dbh->prepare(qq/insert into $listname values($id,?)/) };
       } else {
           # UPDATE
	       my @parts = split '_', $listname; # derive the list field name
	       eval { $sth = $dbh->prepare(qq/update $listname set $parts[2]=? where object=$object_id/) };
       }
       $sth->bind_param(1,$freeze);
       $sth->execute;
       if($@){
	     $dbh->rollback;
	     $self->throw("write operation on table $class_table failed, pending writes were rolled back");                                                     
       }
     }
  }
}

# return a globally unique id string
# insert will require a unique ID. Done here (vs. DB autoincrementing) for portability.
sub _getUID {
  return substr($$.(time % rand(time)),1,9);
}

# decorate the obect_id so that we know its an object_id 
# (versus an integer string) upon reconstitution
sub _wrap {
  my $obj = shift;
  return '%%'. $obj . '%%';
}

# remove decoration from the  object_id
sub _unwrap {
  my $obj = shift;
  $obj =~ s/\%\%//g;
  return $obj;
}

# check if the argument appears to be wrapped
sub _is_wrapped {
  my $obj = shift;
  $obj =~ s/^\%\%\d+\%\%$//;
  $obj ? return 0 : return 1;
}

## freeze lists
sub _freeze {
  my ($parent,$value)=@_;    
    # this is a simple assignment
    unless (ref($value)) {
      return $value;
    }
    # else this is a list assignment
    # iterate over list items
    my $list = [];
    $value = [$value] unless ref($value) eq 'ARRAY';
    foreach my $member (@$value) {                                                                                               
      # compare references => deal with each of the build in types                                                                                                                                         
      if(ref($member) eq ('SCALAR' || 'HASH' || 'CODE' || 'GLOB')) {                                                                                                  
        push @$list, $member;                                                                                                                       
      }                                                                                                                                           
      elsif(ref($member)) { # $member is a user-defined object                                                                          
        unless( $lookup->recall($member) || $member->{'UID'}) {                                                                                
          $member->{'UID'} = $lookup->remember($member);                                           
        }                                                                                                   
        push @$list,$member;                                                                                                 
      }
      else { # this is just a simple assignment                                                                                                   
        push @$list, $member;                                                                                                    
      }
    }                                                                                                                         
    return $list;
}


sub is_query {
  my $answer = $_[0]->session && $_[0] ne $_[0]->session;
}

sub is_connected {
  my($self)=@_;
  $_[0]->dbh;
}


# flattens refs into a list
sub _flatten {  
  my @result = 
  'HASH' eq ref $_[0] ? %{$_[0]} :
    'ARRAY' eq ref $_[0] ?  @{$_[0]} :
    @_;
}


1;

__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB - Almost automatic object persistence -- MySQL only for now

=head1 SYNOPSIS

This class works closely with Class::AutoClass to provide almost
transparent object persistence.

=head2 Define class that uses AutoDB

Define a Person class with attributes 'name', 'sex', and
'friends', where 'friends' is a list of Persons.

  package Class::Person;
  use Class::AutoClass;
  @ISA=qw(Class::AutoClass);

  BEGIN {
    @AUTO_ATTRIBUTES=qw(name sex friends);
    @OTHER_ATTRIBUTES=qw();
    %SYNONYMS=();
    %AUTODB=(
      -collection=>'Person',
      -keys=>qq(name string, sex string, friends list(string)));
    Class::AutoClass::declare(__PACKAGE__);
  }

=head2 Retrieve existing objects

  use Class::AutoDB;
  use Class::Person;
  my $autodb=new Class::AutoDB
      (-database=>'ngoodman',-host=>'socks',-user=>'ngoodman',password=>'bad_password');
  # Query the database
  my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
  print "Number of Joe's in database: ",$cursor->count,"\n";
  while (my $joe=$cursor->get_next) {          # Loop getting the objects one by one
    # $joe is a Person object -- do what you want with it
    my $friends=$joe->friends;
    for my $friend (@$friends) {
      my $friend_name=$friend->name;
      print "Joe's friend is named $friend_name\n";
    }
  }

-- OR -- Get data in one step rather than via loop

  use Class::AutoDB;
  use Class::Person;
  my $autodb=new Class::AutoDB
      (-database=>'ngoodman',-host=>'socks',-user=>'ngoodman',password=>'bad_password');
  my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
  my @joes=$cursor->get;

-- OR -- Run query and get data in one step

  use Class::AutoDB;
  use Class::Person;
  my $autodb=new Class::AutoDB(-dsn=>'dbi:mysql:database=ngoodman;host=socks');
  my @joes=$autodb->get(-collection=>'Person',-name=>'Joe');

-- OR -- Open database and run query in one step

  use Class::AutoDB;
  use Class::Person;
  my $cursor=new Class::AutoDB(
      (-database=>'ngoodman',-host=>'socks',-user=>'ngoodman',password=>'bad_password',
       -find=>{-collection=>'Person',-name=>'Joe'});
  my @joes=$cursor->get;

=head2 Store new objects or update existing ones

  use Class::AutoDB;
  use Class::Person;
  my $autodb=new Class::AutoDB
      (-database=>'ngoodman',-host=>'socks',-user=>'ngoodman',password=>'bad_password');
  my $joe=new Class::Person(-name=>'Joe',-sex=>'male')
  my $mary=new Class::Person(-name=>'Mary',-sex=>'female');
  my $bill=new Class::Person(-name=>'Bill',-sex=>'male');
  # Set up friends lists
  $joe->friends([$mary,$bill]);
  $mary->friends([$joe,$bill]);
  $bill->friends([$joe,$mary]);
  # No need to explicitly store the objects.  AutoDB will store them
  # automatically when they are no longer referenced or when the program ends
  
=head2 Delete existing objects

  use Class::AutoDB;
  my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
  while (my $joe=$cursor->get_next) {          # Loop getting the objects one by one
    $autodb->del($joe);
  }

=head1 DESCRIPTION

This class implements a simple object persistence mechanism. It is
designed to work with Class::Autoclass. 

=head2 Persistence Model

This is how you're supposed to imagine the system works.  The section
on Current Design explains how it really works at present.

Objects are stored in collections. Each collection has any number of
search keys, which you can think of as attributes of an object or
columns of a relational table.  You can search for objects in the
collection by specifying values of search keys.  For example

  my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');

finds all objects in the 'Person' collection whose 'name' key is
'Joe'.  If you specify multiple search keys, the values are ANDed.

The 'find' method also allows almost raw SQL queries with the caveat
that these are very closely tied to the implementation and will not be
portable if we ever change the implementation.

A collection can contain objects from many different classes.  (This
is Perl after all -- what else would you expect ??!!) To limit a
search to objects of a specific class, you can pass a 'class'
parameter to find.  In fact, you can search for objects of a given
class independent of the collection by specifying a 'class' parameter
without a 'collection'.

When you create an object, the system automatically stores it in the
database at an 'appropriate' time, presently just before Perl destroys
the in-memory copy of the object.  (You can also store objects
sooner.)  When you update an object, it gets marked as such, and is
likewise automatically updated in the database.  (Again, you can do
the update manually if you prefer.)

=head2 Set up classes to use AutoDB

To use the mechanism, you define the %AUTODB variable in your
AutoClass definition. (See Class::AutoClass.) If you do not set
%AUTODB, or set it to undef or (), auto-persistence is turned off
for your class.

In the simplest case, you can simply set

  %AUTODB=(1);

This will cause your class to be persistent, using the default
collection name and without any search keys (see Persistence Model
below). 

More typically, you set %AUTODB to a HASH of the form

  %AUTODB=(
    -collection=>'Person', 
    -keys=>qq(name string, sex string, friends list(object)));

  -collection is the name of the collection that will be used to store
   objects of your class, and 
  -keys is a string that defines the search keys that will be defined
   for the class.

The 'keys' string consists of attribute, data type pairs.  Each
attribute is generally an attribute defined in the AutoClass
@AUTO_ATTRIBUTES or @OTHER_ATTRIBUTES variables.  (Technically, it's
the name of a method that can be called with no arguments.) The value
of an attribute must be a scalar, an object reference, or an ARRAY (or
list) of such values.) The data type can be 'string', 'integer',
'float', 'object', any legal MySQL column type, or the phrase
list(<data type>), eg, 'list(integer)'.

NB: At present, only our special data types ('string', 'integer',
'float', 'object') are supported. These can be abbreviated. These are
translated into mySQL types as follows:

  string  => longtext
  integer => int
  float   => double
  object  => int

The 'keys' parameter can also be an array of attribute names, eg,

    -keys=>[qw(name sex)]

in which case the data type of each attribute is assumed to be
'string'.  This works in many cases even if the data is really
numeric.  See Persistence Model below.

The types 'object' and 'list(object)' only work on objects whose
persistence is managed by our Persistence mechanisms.

The 'collection' values may also be an array of collections (and may
be called 'collections') in which case the object is stored in all the
collections.

A subclass need not define %AUTODB, but may instead rely on the
value set by its super-classes. If the subclass does define
%AUTODB, its values are 'added' to those of its super-classes.
Thus, if the suclass uses a different collection than its super-class,
the object is stored in both.  It is an error for a subclass to define
the type of a search key differently than its super-classes.  It is
also an error for a subclass to inherit a search key from multiple
super-classes with different types  We hope this situation is rare!

Technically, %AUTODB is a parameter list for the register
method of Class::AutoDB.  See that method for more details. Some
commonly used slots are

  -skip: an array of attributes that should not be stored.  This is
   useful for objects that contain computed values or other information
   of a transient nature.

  -auto_get: an array of attributes that should be automatically
   retrieved when this object is retrieved.  These should be
   attributes that refer to other auto-persistent objects. This useful
   in cases where there are attributes that are used so often that it
   makes sense to retrieve them as soon as possible.

=head2 Using AutoDB in your code

After setting up your classes to use AutoDB, here's how you
use the mechanism.

The first step is to connect your program to the database.  This is
accomplished via the 'new' method.  

Then you typically retrieve some number of "top level" objects
explcitly by running a query.  This is accomplished via the 'find' and
'get' methods (there are several flavors of 'get').  Then, you operate
on objects as usual.  If you touch an object that has not yet been
retrieved from the database, the system will automatically get it for
you.  You can also manually retrieve objects at any time by running
'get'.

You can create new objects as usual and they will be automatically
written to the database when you're done with them.  More precisely,
the AutoClass DESTROY method writes the object to the database when
Perl determines that the in-memory representation of the object is no
longer needed.  This is guaranteed to happen when the program
terminates if not before.  You can also manually write objects to the
database earlier if you so desire by running the 'put' method.  If you
override DESTROY, make sure you call AutoClass DESTROY in your method.

You can modify objects as usual (almost!) and the system will take
care of writing the updates to the database, just as it does for new
objects.  The one caution is that code that modifies the object must
mark it as 'dirty'.  This is done automatically by methods generated
by AutoClass.  If you write your own mutators, you must do this
yourself by running the 'dirty' method.

=head2 Flavors of 'new', 'find', and 'get'

The examples in the SYNOPSIS use variables named $autodb, $cursor, $joe,
and @joe among others. These names reflect the various stages of data
access that arise.

The first step is to connect to the database.  This is accomplished by
the typical forms of 'new'.  The resulting object (called $autodb
in the SYNOPSIS) is called a 'session' object.  A session object's
main purpose is to run queries.  You can also extract the DBI database
handle from it via the 'dbh' method.

Next a query is sent to the database and executed.  This is typically
accomplished by invoking 'find' on a session object.  The resulting
object (called $cursor in the SYNOPSIS) is called a 'cursor' object.
A cursor object's main purpose is to enable data access.  (DBI
afficionados will recgonize that it's possible to 'prepare' a query
before executing it. This is done under the covers here.)

Finally data is retrieved.  This is typically accomplished by invoking
'get_next' or 'get' on a cursor object.  Data can be retrieved one
object at a time (via 'get_next') or all at once (via 'get').

As a convenience, 'new' can be instructed to automatically do a
'find' or a 'find' followed by a 'get'.  If it does a 'find', it
returns a cursor object; you can get the session from the cursor by
invoking the 'session' method.  If it does a 'find' plus 'get', it
returns a list of retrieved objects.  In this case, the session and
cursor objects are discarded when the method finishes.

Also as a convenience, 'find' can be instructed to do a 'get', and
'get' can be instructed to do a 'find'.  In these cases, the return
value is a list of retrieved objects.

The query executed by 'find' can either be a simple key based search,
or an almost raw, arbitrarily complex SQL query.  The former is
specified by providing key=>value pairs as was done in the SYNOPSIS,
eg,

  $cursor=$autodb->find(-collection=>'Person',-name=>'Joe',-sex=>'male')

The key=>value pairs are ANDed as one would expect.  The above query
retrieves all Persons whoe name is Joe and sex is male.

The raw form is specifed by providing a SQL query (as a string) that
lacks the SELECT phrase, eg,

  $cusror=$autodb->find(qq(FROM Person WHERE name="Joe" AND sex="male"));

To use this form, you have to understand the relational database
schema generated by AutoDB.  This is not portable across
implementations, It's main value is to write complex queries that
cannot be represented in the key=>value form.  For example

  $cusror=$autodb->find(qq(FROM Person p, Person friend, Person_friends friends
                       WHERE p.name="Joe" AND (friend.name="Mary" OR friend.name="Bill")
                       AND friends.person=p));

'find' can also be invoked on a cursor object.  The effect is to AND
the new query with the old.  This only works with the first form
(since conjoining raw SQL is a bear).

=head2 Creating and initializing the database

Before you can use AutoDB, you have to create a MySQL database that
will hold your data.  We do not provide a means to do this here, since
you may want to put your AutoDB data in a database that holds other
data as well.  The databse can be empty or not.  AutoDB creates all th
etables it needs -- you need not (and should not create) these
yourself.

Important note: Hereafter, the term 'database' refers to the tables
created by AutoDB.  Phrases like 'create the database' or 'initialize
the database' refer to these tables only, and not the entire MySQL
database that contains the AutoDB database.

Methods are provided to create or drop the entire database (meaning,
of course, the AutoDB database, not the MySQL database) or individual
collections.

AutoPeristence maintains a registry that describes the collections and
classes stored in the database.  Registration of classes is usually
handled by AutoClass behind the scenes.  The system consults the
registry when creating and dropping the database and when creating
collections.

=head2 Current Design

Caveat: The present implementation assumes MySQL. It is unclear how
deeply this assumption affects the design.

Every object is stored as a BLOB constructed by Data::Dumper.  The
database contains a single 'object table' for the entire database whose
schema is 

create table _AutoDB (
        id int not null auto_increment,
        primary key (id),
        object longblob
        );

The name of this table can be chosen when the database is
created. '_AutoDB' is the default.

For each collection, there is one table we call the base table that
holds scalar serach keys, and one table per list-valued search keys.  

The name of the base table is the same as the name of the collection;
there is no way to change this at present. For our Person example, the
base table would be

create table Person (
        person int,  --- foreign key pointing to  _AutoP_Object, also primary key here
        name longtext,
        sex longtext,
        primary key (person)
        );

If a Person has a significant_other (also a Person), the table would look like this:

create table Person (
        object int,  --- foreign key pointing to _AutoP_Object, also primary key here
        name longtext,
        sex longtext,
        significant_other int -- foreign key pointing to _AutoDB -- will be a Person
        primary key (person)
        );

The data types specified in the 'keys' paramter are used to define the
data types of these columns.  They are also used to ensure correct
quoting of values bound into SQL queries.  It is safe to use 'string'
as the data type even if the data is numeric unless you intend to run
'raw' SQL queries aagainst the database and want to do numeric
comparisons.

For each list valued search key, eg, 'friends' in our example, we need
another table which (no surprise) is a classic link table. The name is
constructed by concatenating the collection name and key name, with a
'_' in between.

create table Person_friends (
        object int,  --- foreign key pointing to Object, also primary key here
        friends int  --- foreign key pointing to Object -- will be a Person
        );

[A small detail: since the whole purpose of these tables is to enable
querying, indexes will be created for each column by default.  This is
not yet implemented.]

When an object is stored in the databse, it obtains a unique object
identifier, called an oid. This is just the id field of the Object
table.  An oid is a permament, immutable identifier for the object.

When the system stores an object, it converts any object references
contained therein into the oids for those objects.  In other words,
objects in the database refer to each other using oids rather than
the in-memory object refereneces used by Perl.  There is no loss of
information since an oid is a permament, immutable identifier for the
object.

When an object is retrieved from the database, the system does NOT
immediately process the oids it contains.  Instead, the system waits
until the program tries to access the referenced object at which point
it automatically retrieves the object from the database.  Options are
provided to retrieve oids earlier.

If a program retrieves the same oid multiple times, the system short
circuits the database access and ensures that only one copy of the
object exists in memory at any point in time. If this weren't the
case, a program could end up with two objects representing Joe, and an
update to one would not be visible in the other.  If both copies were
later stored, one update would be lost.  The core of the solution is
to maintain an in-memory hash of all fetched objects (keyed by object
id). The software consults this hash when asked to retrieve an object;
if the object is already in memory, it is returned without even going
to the database.


=head1 KNOWN BUGS AND CAVEATS

This is still a work in progress.  

=head2 Bugs, Caveats, and ToDos

  TBD

=head1 AUTHOR - Nat Goodman, Chris Cavnor

Email natg@shore.net

=head1 COPYRIGHT

Copyright (c) 2003 Institute for Systems Biology (ISB). All Rights Reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 APPENDIX

The rest of the documentation describes the methods.

=head2 Constructors

 Title   : new
 Usage   : $autodb=new Class::AutoDB
                (-dbd=>'mysql',-database=>'ngoodman',-host=>'socks',
                 -user=>'ngoodman',password=>'bad_password');
 Function: Create AutoDB object. If sufficient parameters are supplied, the 
           object will be connected to the database. By default, opens the
           database for read-write access and creates the database if it does 
           not yet exist. Optionally, runs a query, too.
 Returns : New Class::AutoDB 'session' object unless -find is specified
           New Class::AutoDB 'cursor' object if -find is specified
 Args    : 
 Connection Parameters. These are used in combination to connect to
 the database.  See below for details.

           -dbh        Open database handle for database. 
           -dsn        DBI data source string of the form 
                       "dbi:driver:database_name[:other information]"
                       See documentation for DBI and your DBD driver.
           -dbd        Name of DBD driver. 
                       Default 'mysql' which is also is the only value
                       currently supported
           -host       Hostname of database server
           -server     Synonym for -host
           -user       User name valid for database
           -password   User's password for database

           1) If -dbh is specified, the other parameters are ignored, and the
              existing connection is used.
           2) If -dsn is specified, '-dbd' and '-host' are ignored, and the 
              dsn, user, and password are used to connect.
           3) Else, '-dbd','-database', and '-host' are used to construct a
              dsn which is used to connect to the database.

 Access Parameters.

           -read_only	If true, database is opened in read only mode.
                        Takes precedence over -create, -alter, -drop.  Implies
                        -read_only_schema

          -read_only_schema  Single option to turn off -create, -alter, drop

            1) If true: no schema changes are allowed
            2) If false: schema changes are allowed under control of -create, 
               -alter, -drop

 Schema Modification Parameters.  These control what schema changes
 will be carried out automatically by 'new'. When 'new' connects to
 the database, it reads the registry saved from the last time AutoDB
 ran. It merges this with an in-memory registry that generally
 reflects the currenly loaded classes.  'new; merges the registries,
 and stores the result for next time if the new registry is different
 from the old.  The schema operations described here operate on the
 merged registry.  For example, if you specify -create, what's
 created reflects both the saved registry and whatever new collections
 and search keys are specified in the in-memory registry.

 It is illegal to specify more than one of -drop=>1, -create=>1, and
 -alter=>1.

 When all three options are left unspecified or set to undef, the
 system adopts what we hope is a sensible default: (1) if the database
 does not exist, it is created; and (2) if the database exists, but
 some collections in the in-memory registry do not exist in the
 database, these collections are created.

 Here in detail are the options.

           -create	Controls whether the database may be created

           1) If undef: see default described above
           2) If true: database creation is forced. Ie, the database is
              created whether or not it exists.  
           3) If defined but false: database is not created even if it
              does not exist.  Instead an error is thrown.

           -alter	Controls whether the schema may be altered

           1) If undef: see default described above
           2) If true, schema alterations are allowed to add new
              collections and new search keys to existing collections
           3) If defined but false: schema alerations are not allowed.
              Instead an error is thrown if alterations are required.

           -drop       Controls whether database is automatically dropped

            1) If true, database is dropped.
            2) If false, database is not dropped.

 Query Parameters.  Specify a query to run automatically.

           -find       Parameter list for 'find' method

 Miscellaneous Parameters.

           -object_table Name of AutoDB object table
                         Default: _AutoDB
           -registry     In-memory registry reflecting currently loaded
                         classes.  
                         Default: Class::AutoDB::auto_registy

=head2 Simple attributes

These are methods for getting and setting the values of simple
attributes. Some of these should be read-only (more precisely, should
only be written by code internal to the object), but this is not
enforced.

Methods have the same name as the attribute.  To get the value of
attribute xxx, just say $xxx=$object->xxx; To set it, say
$object->xxx($new_value); To clear it, say $object->xxx(undef);

 Attr    : dsn
 Function: DBI data source string for this database
 Access  : read-write before connection established
           read-only after connection established

 Attr    : dbh
 Function: database handle
 Access  : read-write before connection established
           read-only after connection established

 Attr    : dbd
 Function: database driver name must be 'mysql'
 Access  : read-write before connection established
           read-only after connection established

 Attr    : database
 Function: database name
 Access  : read-write before connection established
           read-only after connection established

 Attr    : host
 Function: database host name
 Access  : read-write before connection established
           read-only after connection established

 Attr    : server
 Function: database server name -- synonym for host
 Access  : read-write before connection established
           read-only after connection established

 Attr    : user
 Function: database user name
 Access  : read-write before connection established
           read-only after connection established

 Attr    : password
 Function: password for database user
 Access  : read-write before connection established
           read-only after connection established

 Attr    : read_only
 Function: Controls whether database is opened in read-only mode
 Access  : read-write before connection established
           read-only after connection established

 Attr    : object_table
 Function: Name of AutoDB object table. 
 Access  : read-write before connection established
           read-only after connection established
 Note    : It is a very serious error to change this while connected to
           the database

 Attr    : registry
 Function: Registry associated with database
 Access  : read-write before connection established
           read-only after connection established

 Attr    : cursors
 Function: list of cursor objects for session
 Access  : read-only

 Attr    : session
 Function: session object for cursor
 Access  : read-only

 Attr    : diff
 Function: RegistryDiff object reflecting changes between saved registry and in-memory
           registry.  Used by alter
 Access  : read-only

=head2 Getting status information about objects

 Title   : is_cursor
 Usage   : print "I'm a cursor object" if $object->is_cursor
 Function: Test whether object represents a cursor
 Args    : None
 Returns : true value if cursor object, else false value

 Title   : is_session
 Usage   : print "I'm a session object" if $object->is_session
 Function: Test whether object represents a session
 Args    : None
 Returns : true value if session object, else false value

 Title   : is_connected
 Usage   : print "Session is connected to database" if $object->is_connected
 Function: Test whether a database is open for object
 Args    : None
 Returns : true value if query has been run, else false

=head2 The registry and schema modification

 Title   : register
 Usage   : $registry=$autodb->register(
              -class=>'Class::Person',
              -collection=>'Person',
              -keys=>qq(name string, sex string, friends list(string)));
 Function: Registers a class/collection with the system
 Args    : -class       => name of class being registered
           -collection  => name of collection that will hold objects, or
                           ARRAY of collection names
           -collections => synonym for -collection
           -keys        => specification of search keys for collection(s) -- see below
           -dont_put    => ARRAY of attributes that will not be stored.  This is
                           useful for objects that contain computed values or other 
                           information of a transient nature.
           -auto_get    => ARRAY of attributes that are automatically retrieved
                           when objects of this class are retrieved. These should be
                           attributes that refer to other auto-persistent objects.
                           This useful in cases where there are attributes that are 
                           used so often that it makes sense to retrieve them as soon 
                           as possible.
  Returns : Class::AutoDBRegistry object

The 'keys' parameter consists of attribute, data type pairs.  Each
attribute is generally an attribute defined in the AutoClass
@AUTO_ATTRIBUTES or @OTHER_ATTRIBUTES variables.  (Technically, it's
the name of a method that can be called with no arguments.) The value
of an attribute must be a scalar, an object reference, or an ARRAY (or
list) of such values.) 

The data type can be 'string', 'integer', 'float', 'object', any legal
MySQL column type, or the phrase list(<data type>), eg,
'list(integer)'.

The 'keys' parameter can also be an array of attribute names, eg,

    -keys=>[qw(name sex)]

in which case the data type of each attribute is assumed to be
'string'.  This works in many cases even if the data is really
numeric as discussed in the Persistence Model section.

The types 'object' and 'list(object)' only work or objects that whose
persistence is managed by AutoDB.

 Title   : create
 Usage   : $autodb->create
 Function: Create (or drop and re-create) AutoDB database
 Args    : None
 Returns : Nothing

 Title   : drop
 Usage   : $autodb->drop
 Function: Drop AutoDB database.
 Args    : None
 Returns : Nothing

 Title   : alter
 Usage   : $autodb->drop
 Function: Alter saved AutoDB database to reflect changes in in-memory registry
 Args    : None
 Returns : Nothing

=cut
