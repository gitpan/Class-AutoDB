package Class::AutoDB::Registry;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Data::Dumper;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Registration;
use Class::AutoDB::Collection;
use Class::AutoDB::StoreCache;
use Class::AutoDB::TypeMap;
@ISA = qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(dbh oid object_table name2coll _exists);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
Class::AutoClass::declare(__PACKAGE__,\@AUTO_ATTRIBUTES,\%SYNONYMS);

use vars qw($REGISTRY $REGISTRY_OID $OBJECT_TABLE $OBJECT_COLUMNS);
$REGISTRY_OID='Registry';		# object id for registry
$OBJECT_TABLE='_AutoDB';	# default for Object table
$OBJECT_COLUMNS=qq(id varchar(15) not null, primary key (id), object longblob);
# global static reference to weak cache
my $sc = Class::AutoDB::StoreCache->instance();
# global static reference to TypeMap
my $tm = new Class::AutoDB::TypeMap;

sub _init_self {
  my($self,$class,$args)=@_;
  $self->_exists(0);
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $self->object_table || $self->object_table($OBJECT_TABLE);
}
sub register {
  my ($self,$args)=@_;
  my $registration=new Class::AutoDB::Registration($args);
  my $name2coll=$self->name2coll || $self->name2coll({});
  my @collections=$registration->collections;
  for my $name (@collections) {
    my $collection=$name2coll->{$name} ||
      ($name2coll->{$name}=new Class::AutoDB::Collection(-name=>$name));
    $collection->register($registration);
  }
  $registration;
}
sub collections {
  my $self=shift;
  my $name2coll=$self->name2coll || $self->name2coll({});
  wantarray? values %$name2coll: [values %$name2coll];
}
sub collection {
  my $self=shift;
  my $name=!ref $_[0]? $_[0]: $_[0]->name;
  my $name2coll=$self->name2coll || $self->name2coll({});
  $name2coll->{$name};
}
sub merge {
  my($self,$diff)=@_;
  $self->throw('merge only operates on RegistryDiff objects') unless (ref($diff) eq 'Class::AutoDB::RegistryDiff');
  my $name2coll=$self->name2coll || $self->name2coll({});
  my $new_collections=$diff->new_collections;
  for my $collection (@$new_collections) {
    my $name=$collection->name;
    $name2coll->{$name}=$collection; # easy case -- just add to registry
  }
  my $expanded_diffs=$diff->expanded_diffs;
  for my $diff (@$expanded_diffs) {
    my $collection=$diff->baseline;
    $collection->merge($diff);   
  }
}
# checks if registry is in db
sub exists {
  my ($self)=@_;
  return 1 if $self->_exists;
  $self->throw('requires a database handle') unless $self->dbh;
  my $object_table=$self->object_table;
  my $tables=$self->dbh->selectall_arrayref(qq(show tables));
  my $exists=grep {lc($object_table) eq lc($_->[0])} @$tables;
  $self->_exists($exists||0);
}
# prepare registry for insertion
sub create {
  my $self=shift;
  my @collections = keys %{$self->{name2coll}} ? _flatten(values %{$self->{name2coll}}) : _flatten(@_);
  $self->throw("Cannot create registry or collections without a connected database") unless $self->dbh;
  # create object table
  my $object_table=$self->object_table;
  my $sql="create table $object_table\($OBJECT_COLUMNS\)";
  $self->dbh->do($sql);
  $self->put;
  $self->_exists(1);
  my @sql=map {$_->schema('create')} @collections;
  for my $sql (@sql) {
    $self->dbh->do($sql);
  }
}

sub drop {
  my $self=shift;
  my @collections=_flatten(@_);
  $self->throw("Cannot drop registry or collections without a connected database") unless $self->dbh;
  unless (@collections) {		# drop registry / leave collections in tact
    my $object_table=$self->object_table;
    my $sql="drop table if exists $object_table";
    $self->dbh->do($sql);
    $self->_exists(0);
  } else {
  	  # have to rewrite registry without deleted collections
  	  map { delete $self->{name2coll}->{$_->name}, "\n" } @collections;
  	  $self->put;
		  my @sql=map {$_->schema('drop')} @collections;
		  for my $sql (@sql) {
		    $self->dbh->do($sql);
		  }
 }
}
sub alter {
  my $self=shift;
  my @diffs=_flatten(@_);
  $self->throw("Cannot drop registry or collections without a connected database") unless $self->dbh;
  my @sql;
  for my $diff (@diffs) {
    my $collection=$diff->other;
    push(@sql,$collection->alter($diff));
  }
  for my $sql (@sql) {
    $self->dbh->do($sql);
  }
}

sub do_sql {
  my $self=shift;
  my @sql=_flatten(@_);
  $self->throw("Cannot run SQL without a connected database") unless $self->dbh;
  for my $sql (@sql) {
    $self->dbh->do($sql);
  }
}

## TODO: fetch and get are the crapiest possible names for these methods - maybe they should
## be named something more descriptive and aliased for user ease
# returns stored registry
sub fetch {
  my ($self)=@_;
  $self->throw('requires a database handle') unless $self->dbh;
  return unless $self->exists;
  my $registry=$self->dbh->selectall_arrayref(qq(select * from $OBJECT_TABLE where id='$REGISTRY_OID'));
	my $thaw;
  eval $registry->[0][1]; # sets thaw
  return bless $thaw, __PACKAGE__; # just in case
}
# returns stored collections
sub get {
  my ($self)=@_;
  $self->throw('requires a database handle') unless $self->dbh;
  if ($self->exists) {		# get from database if it exists
    my $object_table=$self->object_table;
    my($freeze)=$self->dbh->selectrow_array
      (qq(select object from $object_table where id="$REGISTRY_OID"));
    my $thaw;
    eval $freeze;		# sets $thaw
    wantarray ? values %{$thaw->{name2coll}} : [values %{$thaw->{name2coll}}];
  }
}
# insert registry into database
sub put {
  my($self)=@_;
  $self->throw("Cannot put registry without a connected database") unless $self->dbh;
  # Make a shallow copy, deleting transient attributes
  my $copy={_CLASS=>ref($self)};
  while(my($key,$value)=each %$self) {
    next if grep {$key eq $_} qw(autodb _exists dbh);
    $copy->{$key}=$value;
  }
  $tm->load($self->collections); # cache in-memory collections
  my $dumper=new Data::Dumper([undef],['thaw'])->Purity(1)->Indent(1);
  my $freeze=$dumper->Values([$copy])->Dump;
  my $object_table=$self->object_table;
  my $sth = $self->dbh->prepare (qq(replace into $object_table(id, object) values("$REGISTRY_OID",?)));
  $sth->bind_param(1,$freeze);
  $sth->execute;
  if($sth->errstr){
   $self->dbh->rollback;
   $self->throw("write operation on table $object_table failed, pending writes were rolled back");                                           
  }  
  $self->_exists(1); 
}

sub _flatten { 
  map {'ARRAY' eq ref($_) ? @$_: $_} @_; 
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

 -- OR --

 Usage   : $saved_registry=new Class::AutoDB::Registry
                (-autodb=$autodb,
                 -object_table=>'_AutoDB');
 Function: Retrieved saved registry from database
 Args    : -autodb	 AutoDB object for database.  Must be connected!
           -object_table Name of table that stores AutoDB objects
                         Default: _AutoDB
 Returns : Registry object retrieved from the database


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
 
 Title   : get
 Usage   : $got=$registry->get;
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
