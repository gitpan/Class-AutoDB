package Class::AutoDB::Collection;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Table;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

@AUTO_ATTRIBUTES=qw(name _keys _tables _cmp_data);
@OTHER_ATTRIBUTES=qw(register);
%SYNONYMS=();
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}
sub register {
  my $self=shift;
  my @registrations=_flatten(@_);
  my $keys=$self->keys || $self->keys({});

  for my $reg (@registrations) {
    my $reg_keys=$reg->keys;
    while(my($key,$type)=each %$reg_keys) {
      $type=lc $type;
      $keys->{$key}=$type, next unless defined $keys->{$key};
      $self->throw("Inconsistent registrations for search key $key: types are ".$keys->{$key}." and $type") unless $keys->{$key} eq $type;
    }
  }
  $self->_keys($keys);
  $self->_tables(undef);	# clear computed value so it'll be recomputed next time 
}
sub keys {
  my $self=shift;
  my $result= @_? $self->_keys($_[0]): $self->_keys;
  wantarray? %$result: $result;
}
sub merge {
  my($self,$diff)=@_;
  return unless UNIVERSAL::isa($diff, "Class::AutoDB::CollectionDiff");
  my $keys=$self->keys || {};
  my $new_keys=$diff->new_keys;
  warn("merging empty collections") unless (CORE::keys %{$diff->baseline} || CORE::keys %{$diff->other});
  @$keys{CORE::keys %$new_keys}=values %$new_keys;
  $self->keys($keys);
  $self->_tables(undef);	# clear computed value so it'll be recomputed next time 
}
sub alter {
  my($self,$diff)=@_;
  my @sql;
  my $new_keys=$diff->new_keys;
  my $name=$self->name || $self->throw('requires a named collection');
  # Split new keys to be added into scalar vs. list
  my($scalar_keys,$list_keys);
  while(my($key,$type)=each %$new_keys) {
    _is_list_type($type)? $list_keys->{$key}=$type: $scalar_keys->{$key}=$type;
  }
  # New scalar keys have to be added to base table
  # Create a Table object to hold these new keys.
  # Just for programming convenience -- this is not a real table
  my $base_table=new Class::AutoDB::Table (-name=>$name,-keys=>$scalar_keys);
  push(@sql,$base_table->schema('alter'));
  # New list keys have to generate new tables
  while(my($key,$type)=each %$list_keys) {
    my($inner_type)=$type=~/^list\s*\(\s*(.*?)\s*\)/;
    my $list_table=new Class::AutoDB::Table (-name=>$name.'_'.$key,
						-keys=>{$key=>$inner_type});
    push(@sql,$list_table->schema('create'));
  }
  $self->_tables(undef);	# clear computed value so it'll be recomputed next time 
  wantarray? @sql: \@sql;
}
sub tables {
  my $self=shift;
  return $self->_tables(@_) if @_;
  unless (defined $self->_tables) {
    my $name=$self->name || $self->warn("no collection name specified, using system default: $Class::AutoDB::Registry::OBJECT_TABLE");
    # Collection has one 'base' table for scalar keys and one 'list' table per list key
    #
    # Start by splitting keys into scalar vs. list
    my $keys=$self->keys;
    my($scalar_keys,$list_keys);
    while(my($key,$type)=each %$keys) {
      _is_list_type($type)? $list_keys->{$key}=$type: $scalar_keys->{$key}=$type;
    }
    my $base_table=new Class::AutoDB::Table (-name=>$name,-keys=>$scalar_keys);
    my $tables=[$base_table];
    while(my($key,$type)=each %$list_keys) {
      my($inner_type)=$type=~/^list\s*\(\s*(.*?)\s*\)/;
      my $list_table=new Class::AutoDB::Table (-name=>$name.'_'.$key,
						  -keys=>{$key=>$inner_type});
      push(@$tables,$list_table);
    }
    $self->_tables($tables);
  }
  wantarray? @{$self->_tables}: $self->_tables;
}
sub schema {
  my($self,$code)=@_;
  my @sql=map {$_->schema($code)} $self->tables;
  wantarray? @sql: \@sql;
}
sub tidy {
  my $self=shift;
  $self->_tables(undef);
}

sub _is_list_type {
  $_[0]=~/^list\s*\(/;
}
sub _flatten {
	map {'ARRAY' eq ref($_) ? @$_: $_} @_;
}
  
1;

__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::Collection - registration information for one collection

=head1 SYNOPSIS

This is a helper class for Class::AutoDB::Registration which
represents the registration information for one collection

  use Class::AutoDB::Collection;
  my $collection=new Class::AutoDB::Collection(-name=>'Person');
  $collection->register($registration);
  my $name=$collection->name; 
  my $keys=$collection->keys;	  # returns hash of key=>type pairs
  my $tables=$collection->tables;           # tables that implement this collection
                                            # returns Class::AutoDB::Table objects
  my @sql=$collection->schema;              # list of SQL statements needed to create collection
  my @sql=$collection->schema('create');    # same as above
  my @sql=$collection->schema('drop');      # list of SQL statements needed to drop collection
  my @sql=$collection->schema('alter',TBD); # list of SQL statements needed to alter
                                            # collection to reflect changes in TBD
=head1 DESCRIPTION

This class represents processed registration information for one
collection. Registrations are fed into the class via the 'register'
method which combines the information to obtain a single hash of
key=>type pairs.  It makes sure that if the same key is registered
multiple times, it has the same type each time.

It further processes the information to determine the database tables
needed to implement the collection, and the SQL statements needed to
create, and drop thoses tables.  It also has the ability to compare
its current state to TBD and generate the SQL statements needed to
alter the current schema the new one.  Details TBD.

Also TBD: does this class talk to the database or just generate SQL?

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

 Usage   : $collection=new Class::AutoDB::Collection(-name=>'Person');
 Function: Create object
 Returns : New Class::AutoDB::Collection object
 Args    : -name	name of collection being registered

=head2 Simple attributes

These are methods for getting and setting the values of simple
attributes.  Some of these should be read-only (more precisely, should
only be written by code internal to the object), but this is not
enforced. 

Methods have the same name as the attribute.  To get the value of
attribute xxx, just say $xxx=$object->xxx; To set it, say
$object->xxx($new_value); To clear it, say $object->xxx(undef);

 Attr    : name 
 Function: name of table that registered 
 Access  : read-only

=head2 register

 Title   : register
 Usage   : $collection->register(@registrations)
 Function: Add a list of registrations to collection.  The method processes them
           to obtain a single hash of key=>type pairs. It makes sure that if the 
           same key is registered multiple times, it has the same type each time.
 Args    : array or ARRAY ref of Class::AutoDB::Registration objects that pertain 
           to this collection
 Returns : Nothing

 Title   : merge
 Usage   : $collection->merge($diff)
 Function: Add search keys to collection as specified by diff
 Args    : CollectionDiff comparing saved collection to new one
 Returns : Nothing

 Title   : alter
 Usage   : $collection->alter($diff)
 Function: Generate SQL to change database to reflect addition of new search keys 
           to collection as specified by diff
 Args    : CollectionDiff comparing saved Collection to in-memory version
 Returns : array or ARRAY ref of SQL statements (as strings) needed to effect
           change in database

=head2 keys

 Title   : keys
 Usage   : %keys=$collection->keys
           -- OR --
           $keys=$collection->keys
 Function: Returns key=>type pairs for key registered for this collection
 Args    : None
 Returns : hash or HASH ref of key=>type pairs

=head2 tables

 Title   : tables
 Usage   : @tables=$collection->tables
           -- OR --
           $tables=$collection->tables
 Function: Returns Class::AutoDB::Table objects for relational tables needed
           to implement collection
 Args    : None
 Returns : array or ARRAY ref of Class::AutoDB::Table objects

=head2 schema

 Title   : schema
 Usage   : @sql=$collection->schema
           -- OR --
           @sql=$collection->schema($code)
           -- OR --
          $sql=$collection->schema
           -- OR --
           $sql=$collection->schema($code)
 Function: Returns SQL statements needed to create, drop, or alter the tables
           that implement collection
 Args    : Code that indicates what schema operation is desired
           'create' -- default
           'drop'
           'alter' -- requires additional argument: CollectionDiff
 Returns : array or ARRAY ref of SQL statements (as strings)

=cut

