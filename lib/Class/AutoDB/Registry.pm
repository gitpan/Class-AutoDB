package Class::AutoDB::Registry;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Data::Dumper;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Registration;
use Class::AutoDB::RegistryDiff;
use Class::AutoDB::Collection;
use Class::AutoDB::StoreCache;
use Class::AutoDB::TypeMap;
use Storable;    # for dclone
@ISA = qw(Class::AutoClass);

@AUTO_ATTRIBUTES  = qw(dbh oid object_table collection_table name2coll _exists);
@OTHER_ATTRIBUTES = qw();
%SYNONYMS         = (get_collections=>'get');
Class::AutoClass::declare( __PACKAGE__, \@AUTO_ATTRIBUTES, \%SYNONYMS );

use vars qw($REGISTRY $REGISTRY_OID $OBJECT_TABLE $COLLECTION_TABLE);
$REGISTRY_OID     = 'Registry';        # object id for registry
$OBJECT_TABLE     = '_AutoDB';         # default for object table
$COLLECTION_TABLE = 'collection_link';    # default for collections lookup table

# global static reference to weak cache
my $sc = Class::AutoDB::StoreCache->instance();

# global static reference to TypeMap
my $tm = new Class::AutoDB::TypeMap;

sub _init_self {
 my ( $self, $class, $args ) = @_;
 $self->_exists(0);
 return unless $class eq __PACKAGE__;    # to prevent subclasses from re-running this
 my $dbh = $args->{dbh} || $args->{autodb}->{registry}->{dbh};
 if ( $dbh ) {
  $self->dbh($dbh);
  $self->object_table( $args->object_table || $OBJECT_TABLE );
  # AutoClass expects to send back an AutoClass object, so we switch it here
  my $res = $self->_retrieve($self->object_table);
  $self = Storable::dclone($res);
  return $self;
 }
 $self->object_table     || $self->object_table($OBJECT_TABLE);
 $self->collection_table || $self->collection_table($COLLECTION_TABLE);
}

sub register {
   my $self = shift;
   my $args = @_;
   my $collection;
   my $name2coll = $self->name2coll || $self->name2coll( {} );
   $args = new Class::AutoClass::Args(@_)
     unless ref $args eq 'Class::AutoClass::Args';
   my $registration = new Class::AutoDB::Registration($args);
   foreach my $collection_name (@{$registration->_collection}) {
     $collection = new Class::AutoDB::Collection(-name => $collection_name);
     $collection->register($registration);
     # handle in-memory merges (inheritance)
     if($sc->exists($collection_name)) {
	     	my $prior = $self->collection($collection_name);
	     	$collection->merge(new Class::AutoDB::CollectionDiff(-baseline=>$collection,-other=>$prior));
     }
     $name2coll->{$collection_name}=$collection;
     # remember what collections this class belongs to
     $sc->cache( $registration->class, $registration->_collection );
   }
   return $self;
}

sub collections {
 my $self = shift;
 my $name2coll = $self->name2coll || $self->name2coll( {} );
 wantarray ? values %$name2coll : [ values %$name2coll ];
}

sub collection {
 my $self = shift;
 my $name = !ref $_[0] ? $_[0] : $_[0]->name;
 $self->name2coll->{$name};
}

sub merge {
 my ( $self, $diff ) = @_;
 $self->throw('merge only operates on RegistryDiff objects')
   unless ( ref($diff) eq 'Class::AutoDB::RegistryDiff' );
 my $name2coll = $self->name2coll || $self->name2coll( {} );
 my $new_collections = $diff->new_collections;
 for my $collection (@$new_collections) {
  my $name = $collection->name;
  $name2coll->{$name} = $collection;    # easy case -- just add to registry
 }
 my $expanded_diffs = $diff->expanded_diffs;
 for my $diff (@$expanded_diffs) {
  my $collection = $diff->baseline;
  $collection->merge($diff);
 }
}

# checks if registry is in db
sub exists {
   my ($self) = @_;
   return 1 if $self->_exists;
   $self->throw('requires a database handle') unless $self->dbh;
   my $object_table = $self->object_table;
   my $tables       = $self->dbh->selectall_arrayref(qq(show tables));
   my $exists       = grep { lc($object_table) eq lc( $_->[0] ) } @$tables;
   $self->_exists( $exists || 0 );
}

# create tables in database for registry and all current collections
sub create {
   my ($self,@collections)=@_;
   @collections = _flatten(@collections);
   my $ot = $self->object_table || $self->object_table($OBJECT_TABLE);
   # either collection names or collection objects can be passed - normalize to objects
   # otherwise, use what is in the in-memory registry
   if (@collections) {
    @collections =
      map {
     ref($_) eq 'Class::AutoDB::Collection'
       ? $_
       : new Class::AutoDB::Collection( -name => $_ )
      } @collections;
   }
   else {
    @collections = values %{ $self->{name2coll} };
   }
   $self->throw(
    "Cannot create registry or collections without a connected database")
     unless $self->dbh;
   # create object table
   my $OBJECT_COLUMNS =
     #qq(oid varchar(15) not null, primary key (oid), object longblob);
     qq(oid varchar(15) not null, primary key (oid), object longblob, last_modified timestamp(12) not null);
   my $COLLECTION_COLUMNS =
     qq(oid varchar(15) not null, class_name varchar(255) not null, collection_name varchar(255) not null);
   my $sql = "create table $ot\($OBJECT_COLUMNS\)";
   $self->dbh->do($sql);
   foreach my $collection (@collections) {
    next unless $collection->{name}; # unnamed collections cannot be persisted
    $self->{name2coll}{ $collection->name } = $collection;
   }
   my @sql = map { $_->schema('create') } @collections;
   for my $sql (@sql) {
    next unless $sql;
    $self->dbh->do($sql);
   }
   # create collection lookup table
   $sql = "create table $COLLECTION_TABLE \($COLLECTION_COLUMNS\)";
   $self->dbh->do($sql);
}

 # get saved registry and compare with in-memory registry.
sub diff {
 my $in_memory=shift;
 my $dbh = shift;
 my $saved;
 if ($in_memory->exists) {
   $saved=$in_memory->_retrieve;
 } else {
   $saved=$in_memory;
 }
 return new Class::AutoDB::RegistryDiff(-baseline=>$saved,-other=>$in_memory);
}

sub drop {
 my $self = shift;
 my @collection_names = @_;
 $self->throw(
  "Cannot drop registry or collections without a connected database")
   unless $self->dbh;
 unless (scalar @collection_names) {    # drop entire registry
  my $object_table = $self->object_table;
  my $sql          = "drop table if exists $object_table";
  $self->dbh->do($sql);
  undef $self->{name2coll};
  $self->_exists(0);
 }
 else {                          # drop just the requested collection tables
  map { delete $self->{name2coll}->{$_} } @collection_names;
  $self->put;
 }
}

sub alter {
 my $self  = shift;
 my @diffs = _flatten(@_);
 $self->throw(
  "Cannot drop registry or collections without a connected database")
   unless $self->dbh;
 my @sql;
 for my $diff (@diffs) {
  my $collection = $diff->other;
  push( @sql, $collection->alter($diff) );
 }
 for my $sql (@sql) {
  $self->dbh->do($sql);
 }
}

sub do_sql {
 my $self = shift;
 my @sql  = _flatten(@_);
 $self->throw("Cannot run SQL without a connected database") unless $self->dbh;
 for my $sql (@sql) {
  $self->dbh->do($sql);
 }
}

# get the frozen registry from the data store
sub _retrieve {
 no warnings; # supress unitialized warnings
 my ($self,$object_table) = @_;
 $self->throw('requires a database handle') unless $self->dbh;
 $object_table ||= $self->object_table;
 my ($freeze) =
   $self->dbh->selectrow_array(
  qq(select object from $object_table where oid="$REGISTRY_OID"));
 my $thaw;
 eval $freeze;    # sets $thaw
 return bless $thaw, $thaw->{_CLASS};
}

# returns stored collections
sub get {
 my ($self) = @_;
 $self->throw('requires a database handle') unless $self->dbh;
 if ( $self->exists ) {    # get from database if it exists
  my $thaw = $self->_retrieve;
  wantarray
    ? values %{ $thaw->{name2coll} }
    : [ values %{ $thaw->{name2coll} } ];
 }
 else {
  return undef;
 }
}

# insert registry into database (which was created by Registry)
sub put {
 my ($self) = @_;
 $self->throw("Cannot put registry without a connected database")
   unless $self->dbh;
 # Make a shallow copy, deleting transient attributes
 my $copy = { _CLASS => ref($self) };
 while ( my ( $key, $value ) = each %$self ) {
  next if grep { $key eq $_ } qw(autodb _exists dbh);
  $copy->{$key} = $value;
 }
 $tm->load( $self->collections );    # cache in-memory collections
 my $dumper = new Data::Dumper( [undef], ['thaw'] )->Purity(1)->Indent(1);
 my $freeze = $dumper->Values( [$copy] )->Dump;
 my $object_table = $self->object_table;
 my $sth          =
   $self->dbh->prepare(
  qq(replace into $object_table(oid, object) values("$REGISTRY_OID",?)));
 $sth->bind_param( 1, $freeze );
 $sth->execute;

 if ( my $e = $sth->errstr ) {
  $self->dbh->rollback;
  $self->throw("$e: write operation on table $object_table failed, make sure that Registry::create was called before put");
 }
 $sc->cache( $REGISTRY_OID, $freeze );    # cache the frozen registry
 $self->_exists(1);
}

sub _flatten {
 return undef unless $_[0];
 map { 'ARRAY' eq ref($_) ? @$_ : $_ } @_;
}

1;

__END__

	# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::Registry - Database registry for Class::AutoDB

=head1 SYNOPSIS

Used by Class::AutoDB to keep track of the classes and collections
being managed by the AutoDB system.  Most users will never use this
class explicitly. The synopsis show approximately how the class is
used by AutoDB itself.

  use Class::AutoDB;
  use Class::AutoDB::Registry;
  $autodb=new Class::AutoDB(
		      -dsn=>'dbi:mysql:database=some_database;host=some_host',
 		      -user=>'some_user',
		      -password=>'some_password');
  my $registry=new Class::AutoDB::Registry;
  $registry->register(
               -class=>'Class::Person',
               -collection=>'Person',
               -keys=>qq(name string, sex string, friends list(string)));
  @collections=$registry->collections;      # return all collections that have 
                                            # been registered
  my $saved_registry=new Class::AutoDB::Registry
         (-autodb=>$autodb,
          -object_table=>'_AutoDB_Object');# get saved registry from database

  $saved_registry->put;                 # store it in database for next time

  # Other commonly used methods

  $registry->drop;		          # drop entire database
  $registry->drop('Person');              # drop one collection
  $registry->create;                      # create entire database
  $registry->create('Person');            # create one collection

=head1 DESCRIPTION

This class maintains the schema information for an AutoDB
database.  There should only be one registry per database (since a registry 
is meant to define a database), but there can be two versions of it. 

1.  An in-memory version generated by calls to the 'register'
    method.  This method is usually called automatically when
    AutoClass processes %AUTODB declarations from classes as
    they are loaded.  The 'register' method can also be called
    explicitly at runtime.

2.  A database version. The stored version is supposed to reflect
    the real structure of the AutoDB database.  (Someday we
    will provide a method for confirming this.)

Before the AutoDB mechanism can run, it must ensure that the
in-memory version is self-consistent, and that the in-memory and
database versions are mutually consistent.  (It doesn't have to check
the database version for self-consistency since the software won't
store an inconsistent version.)

The in-memory version is inconsistent if the same search key is
registered for a collection with different data types.  The in-memory
and database versions are inconsistent if the combination has this
property.

The in-memory and database versions of the registry can be different
but consistent if the running program registers only a subset of the
collections that are known to the system, or registers a subset of the
search keys for a collection.  This is a very common case and requires
no special action.

The in-memory and database versions can also be different but
consistent if the running program adds new collections or new search
keys to an existing collection.  In this case, the database version of
the registry and the database itself must be updated to reflect the
new information.  Methods are provided to effect these changes.

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

 Usage   : $registry=new Class::AutoDB::Registry;
 Function: Create new empty registry
 Returns : New registry object
 Args    : none
 Notes   : for in-memory registries

 -- OR --
 
 Usage   : $registry=new Class::AutoDB::Registry(-dbh=>$dbh);
 Function: Create new empty (but persistable) registry
 Returns : New registry object
 Args    : database handle
 Notes   : you must call can $registry->create to create the registry schema,
           then call $registry->put to perist your in-memory registry with its collections
 
 -- OR --

 Usage   : $saved_registry=new Class::AutoDB::Registry
                (-autodb=$autodb,
                 -object_table=>'_AutoDB');
 Function: Retrieved saved registry from database
 Args    : -autodb	 AutoDB object for database.  Must be connected!
           -object_table Name of table that stores AutoDB objects
                         Default: _AutoDB
 Returns : Registry object retrieved from the database
 Notes   : AutoDB obj argument will implicitly call $registry->create for you.

=head2 Simple attributes

These are methods for getting and setting the values of simple
attributes. Some of these should be read-only (more precisely, should
only be written by code internal to the object), but this is not
enforced. 

Methods have the same name as the attribute.  To get the value of
attribute xxx, just say $xxx=$object->xxx; To set it, say
$object->xxx($new_value); To clear it, say $object->xxx(undef);

 Attr    : autodb
 Function: Class::AutoDB object connected to database
 Access  : read-write

 Attr    : oid
 Function: Object id of saved registry
 Access  : read-only

 Attr    : registrations
 Function: array or ARRAY ref of registrations
 Access  : read-only (no mutator provided even for internal use)

 Attr    : coll2reg
 Function: hash or HASH ref mapping collection names to registrations
 Access  : read-only (no mutator provided even for internal use)


=head2 collections

 Title   : collections
 Usage   : $collections=$registry->collections;
          -- OR --
           @collections=$registry->collections;
 Function: Return collections contained in registry
 Args    : None
 Returns : array or ARRAY ref of Class::AutoDB::Collection objects

 Title   : collection
 Usage   : $collection=$registry->collection($collection);
 Function: Return collection object
 Args    : Name of collection or collection object. 
 Returns : Class::AutoDB::Collection object
 
 Title   : get_collections (synonym: get)
 Usage   : $got=$registry->get;
           -- OR --
           @got=$registry->get;
 Function: Return a Registry object containing all stored collections
 Args    : None. 
 Returns : a Class::AutoDB::Registry object containing Class::AutoDB::Collection objects

 Title   : merge
 Usage   : $registry->merge($diff));
 Function: Merge differences into registry
 Args    : Class::RegistryDiff object reflecting difference between this registry 
           and a new one       
 Returns : Nothing

If the registry does not contain a collection of the same name, the
new collection is simply added to the registry. If the registry
contains a collection of the same name, the information from the new
collection is merged with the existing collection.  It is an error if
the merged information is not consistent.

=head2 Operations that touch the database

These methods read or write the actual database structure. They are only
legal if the registry is connected to the database.

 Title   : exists
 Usage   : $registry->exists
 Function: Tests whether the registry exists in the database
 Args    : None
 Returns : 0 or 1 indicate the registry does not or does exist
           undef is used internally to indicate that we don't know the answer

The registry is declared to exist if the AutoDB object table exists in
the database.  The method checks whether this is so and caches the
result in the _exists attribute.  Subsequent calls use the cached
version.  The create and drop methods update _exists.

 Title   : create
 Usage   : $registry->create
           -- OR --
           $registry->create(@collections)
 Function: Create entire registry or tables needed to implement the listed 
           collections
 Args    : array or ARRAY ref of 0 or more collection names or objects
 Returns : Nothing

With no arguments, this creates the entire registry including the
AutoDB object table.  If the registry already exists, it is dropped
first.

With arguments, the method just creates the tables needed to implement
the listed collections.  If the tables already exist, they are dropped
first. In this case, it is an error if the registry does not already
exist.

 Title   : drop
 Usage   : $registry->drop
           -- OR --
           $registry->drop(@collections)
 Function: Drop entire registry or tables needed to implement the listed 
           collections
 Args    : array or ARRAY ref of 0 or more collection names or objects
 Returns : Nothing

With no arguments, this drops the entire registry including the AutoDB
object table. With arguments, the method just drops the tables needed
to implement the listed collections.

In both cases, the code tries to do the drop even if it appears the
registry does not exist.

 Title   : alter
 Usage   : $registry->alter(@diffs)
 Function: Expand collections to reflect the diffs
 Args    : array or ARRAY ref of 0 or more CollectionDiffs
 Returns : Nothing

Each argument is a CollectionDiff that compares the saved registry
with a new one.  Each should be an expanded collection.  The method
alters and creates the tables needed to implement the changes.

 Title   : do_sql
 Usage   : $registry->do_sql(@sql);
 Function: Utility function to run SQL statements
 Args    : array or ARRAY ref of SQL statements (as strings)
 Returns : Nothing

IT is an error if the registry does not already exist.

 Title   : put
 Usage   : $registry->put
 Function: Store registry in database
 Args    : Nothing
 Returns : Object id for registry (always the same at present)

=cut
