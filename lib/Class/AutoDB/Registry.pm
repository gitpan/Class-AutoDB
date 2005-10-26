package Class::AutoDB::Registry;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Text::Abbrev;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::RegistryVersion;
use Class::AutoDB::RegistryDiff;
use Class::AutoDB::Registration;
use Class::AutoDB::Collection;
use Class::AutoDB::Serialize;
@ISA = qw(Class::AutoClass Class::AutoDB::Serialize);

use vars qw($REGISTRY_OID);
$REGISTRY_OID=1;		# object id for registry

@AUTO_ATTRIBUTES=qw(autodb name2coll current saved diff);
@OTHER_ATTRIBUTES=qw(oid);
%SYNONYMS=();
%DEFAULTS=();
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $self->get;			# get or initialize saved version. also inits current version
}
sub oid {$REGISTRY_OID}		# do it this way so oid is set when Serialize
                                # constructor called
sub register {
  my $self=shift;
  $self->current->register(@_);
}
sub collections {
  my $self=shift;
  $self->current->collections;
}
sub collection {
  my $self=shift;
  $self->current->collection(@_);
}
sub class2colls {
  my $self=shift;
  $self->current->class2colls(@_);
}

sub merge {
  my($self)=@_;
  my $current=$self->current;
  my $saved=$self->saved;
  my $diff=new Class::AutoDB::RegistryDiff(-baseline=>$saved,-other=>$current);
  $self->diff($diff);		# hang onto this since it's expensive to compute
  $saved->merge($diff);
}

my @WHATS=qw(create drop alter);
my %WHATS=abbrev @WHATS;

sub schema {
  my($self,$what,$index_flag)=@_;
  $what or $what='create';
  $index_flag = defined $index_flag ? $index_flag : 1; # indexing is default operation
  $what=$WHATS{lc($what)} || $self->throw("Invalid \$what for schema: $what. Should be one of: @WHATS");
  my @sql;
  if ($what eq 'create') {	# create current collections
    push(@sql,map {$_->drop} $self->saved->collections); # drop existing collections first
    push(@sql,map {$_->create($index_flag)} $self->current->collections); # then create new ones
  } elsif ($what eq 'drop') {	# drop current & saved collections
    push(@sql,map {$_->drop} $self->saved->collections);
    push(@sql,map {$_->drop} $self->current->collections);
  } else {			# it's alter
    my $diff=$self->diff;
    my $new_collections=$diff->new_collections;
    push(@sql,map {$_->create} @$new_collections);
    my $expanded=$diff->expanded_diffs;
    for my $diff (@$expanded) {
      my $collection=$diff->other;
      push(@sql,$collection->alter($diff));
    }
  }
  wantarray? @sql: \@sql;
}
sub get {			# retrieve saved registry
  my($self)=@_;
  # save transient state across fetch
  my $autodb=$self->autodb;
  my $current=$self->current;
  # !! fetch overwrites entire object !!
  Class::AutoDB::Serialize::really_fetch($REGISTRY_OID,$self) if $autodb && $autodb->exists;
  # initialize saved if necessary
  $self->saved or $self->saved(new Class::AutoDB::RegistryVersion(-registry=>$self));
  # restore transient state. initialize current if necessary
  $self->autodb($autodb);
  $self->current($current || new Class::AutoDB::RegistryVersion(-registry=>$self));
}
sub put {			# store saved registry
  my($self)=@_;
  # save and clear transient state. TODO: use 'transients' when implemented
  my $autodb=$self->autodb;
  my $current=$self->current;
  my $diff=$self->diff;
  $self->autodb(undef);
  $self->current(undef);
  $self->diff(undef);
  $self->store;			# Class::AutoDB::Serialize::store
  # restore transient state
  $self->autodb($autodb);
  $self->current($current);
  $self->diff($diff);
}

sub _flatten {map {'ARRAY' eq ref $_? @$_: $_} @_;}

1;

__END__

=head1 NAME

Class::AutoDB::Collection - Schema information for an AutoDB database

=head1 SYNOPSIS

This a major subsystem of Class::AutoDB which keeps track of the
classes and collections being managed by the AutoDB system. Most users
will never use this class explicitly. The synopsis show approximately
how the class is used by AutoDB itself.

 use Class::AutoDB;
 use Class::AutoDB::Registry;
 my $autodb=new Class::AutoDB(-database=>'test');
 my $registry=new Class::AutoDB::Registry(-autodb=>$autodb);
 $registry->register
   (-class=>'Person',
    -collection=>'Person',
    -keys=>qq(name string, sex string, friends list(string)));
 @registrations=$registry->registrations;# all registrations
 @collections=$registry->collections;    # all collections
 
 confess "Current registry inconsistent with saved one" 
   unless $registry->is_consistent;
 if ($registry->is_different && !$registry->is_sub {
                                       # current registry expands 
                                       #   saved registry
   $registry->alter;                   # SQL statements to change
                                       #   database structure to
                                       #   reflect changes
 }
 $registry->put;                       # store in database for next time
 
 # Other commonly used methods
 $registry->create;                    # SQL statements to create database
 $registry->drop;                      # SQL statements to drop database

=head1 DESCRIPTION

This class maintains the schema information for an AutoDB database.
There can only be one registry per database and you should only have
one registry object in your program. The registry object may contain
two versions of the registry.

=over

=item 1.

An in-memory version generated by calls to the 'register' method. This
method is usually called automatically when AutoClass proceses
%AUTO_PERSISTENCE declarations from classes as they are loaded. The
'register' method can also be called explicitly at runtime.

=item 2.

2. A version saved in the database. The database version is supposed to
reflect the real structure of the AutoDB database. (Someday we will
provide a method for confirming this.)

=back

Before the AutoDB mechanism can run, it must ensure that the in-memory
version of the registry is self-consistent, and that the in-memory and
database versions are mutually consistent. (It doesn't have to check
the database version for self-consistency since the software won't
store an inconsistent version.) The in-memory version is inconsistent
if the same search key is registered for a collection with different
data types. The in-memory and database versions are inconsistent if the
combination has this property.

The in-memory and database versions of the registry can be I<different
but consistent> if the running program registers only a subset of the
collections that are known to the system, or registers a subset of the
search keys for a collection. This is a very common case and requires
no special action.

The in-memory and database versions can also be I<different but
consistent> if the running program adds new collections or new search
keys to an existing collection. In this case, the database version of
the registry and the database itself must be updated to reflect the new
information. Methods are provided to effect these changes.

This class I<talks to the database>.

=head1 BUGS and WISH-LIST

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Registry.html#bugs_and_wishlist>

=head1 METHODS and FUNCTIONS - Initialization

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Registry.html#methods_and_functions>


=cut