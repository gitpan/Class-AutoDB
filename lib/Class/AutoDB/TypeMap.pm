package Class::AutoDB::TypeMap;
use strict;
use base qw(Class::AutoClass Class::AutoDB::Cache);
use vars qw(@AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use Class::AutoDB::Collection;

@AUTO_ATTRIBUTES=qw();
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
Class::AutoClass::declare(__PACKAGE__);

my $coll = new Class::AutoDB::Collection;

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $self->load($args) if $args;
  return __PACKAGE__->instance();
}

sub load {
  my($self,@args)=@_;
  my $flag = 0;
  my $norm_colls = _normalize(\@args);
  foreach my $collection ( @{$norm_colls} ) {
    $self->cache($collection->{name}, $collection);
    $flag = 1;
  }
  return $flag;
}

sub count {
 my $self=shift;
 return $self->SUPER::count();
}

sub keys_for {
  my($self,$coll_name)=@_;
  return $self->SUPER::recall($coll_name)->keys;
}

sub type_of {
  my($self,$key,$coll_name)=@_;
  $self->throw("value_of requires a key and collection name") unless $coll_name;
  return $self->keys_for($coll_name)->{$key};
}

# checks a small number of fundimental types for bounds and reasonable values.
# only the documented types are checked - all others pass through unfiltered.
sub is_valid {
  my($self,$type,$value)=@_;
  my $flag = 0;
  $self->throw("is_valid requires a key and value") 
    unless defined $type and defined $value;
  if ($type eq 'string') {
    $flag = 1 unless ref $value;
  } elsif ($type eq 'int' || $type eq 'signed') { # signed int by default
    $flag = 1 if 
      $value =~ /^\-?\d+$/o   and
      $value >= -2147483648   and
      $value <= 2147483647;
  } elsif ($type eq 'unsigned') {
    $flag = 1 if 
      $value =~ /^\d+$/o   and
      $value >= 0          and
      $value <= 4294967295;
  } elsif ($type eq 'float') {
    $flag = 1 if 
      $value =~ /^\-?\d+$/o; # NOTE: no size checks
  } elsif ($type eq 'object') {
    $flag = 1 if $self->is_inside($value);
  # list handling
  } elsif ($type =~ /list\((.*)\)/) {
      $self->throw('list must be an array ref') unless ref($value) eq 'ARRAY';
      my $cnt = scalar @$value;
      my $ok_cnt = 0;
      if ($1 =~ /string/) {
        foreach (@$value) {
          $ok_cnt++ unless ref $_;
        }
        $flag = 1 if $ok_cnt == $cnt;
      } elsif ($1 =~ /object/) {
          foreach (@$value) {
            $ok_cnt++  if $self->is_inside($_);
          }
        $flag = 1 if $ok_cnt == $cnt;
      } elsif ($1 =~ /mixed/ or not $1) { # mixed type
          foreach (@$value) {
            $ok_cnt++  if 
              $self->is_inside($_) or not
              ref $_;
          }
        $flag = 1 if $ok_cnt == $cnt;
      }
  } else {
     # huge leap of faith - assuming that user is paying attention
     # to their type constraints.
     $self->warn("no checking was done for $type with value $value");
     $flag = 1; 
  }
  return $flag;
}

# scrubs values (including list values) in simple ways:
#  dereferences values for string types and flattens value(s),
#  extracts forbidden types from lists (ex: removes strings from object types)
sub clean {
  my($self,$type,$value)=@_;
  $self->throw("is_valid requires a key and value") unless defined $type and defined $value;
  my @result;
  
  if ($type eq 'string') {
    return $self->_deref($value);
  # list handling
  } elsif ($type =~ /list\((.*)\)/) {
      $self->throw('list must be an array ref') unless ref($value) eq 'ARRAY';
      if ($1 =~ /string/) {
        foreach (@$value) {
          push @result, $self->_deref($_) || next;
        }
      } elsif ($1 =~ /object/) {
          foreach (@$value) {
            push @result, $_ if $self->is_inside($_);
          }
      } elsif ($1 =~ /mixed/) { # mixed type
          foreach (@$value) {
            push @result, $_  if 
              $self->is_inside($_) or
              $self->_deref($_);
          }
      }             
      return @result ? \@result : undef;
  }
}

# deref scalar and ref types. Prep for string insertion
sub _deref {
  no warnings;
  my ($self,$value) = @_;
  my $ref = ref $value || return $value;
  if ( $ref eq 'SCALAR') { return $$value }
  elsif ( $ref eq 'ARRAY') { return "@$value" }
  elsif ( $ref eq 'HASH') { return "%$value" }
  else { return undef }
}

# determines if object argument is an object, 
# either inside (AutoDB able) or outside (foreign object)
sub is_object {
  my ($self,$obj) = @_;
  return
    $self->is_outside($obj) or 
    $self->is_inside($obj)  ?
    1 : 0;
}

# return true if $object is an outside object (not AutoDB able)
# and not a reference to an array block (lists are ok).
sub is_outside {
  my ($self,$obj) = @_;
  my $ref = ref($obj);
  return
    (not $self->_deref($obj)                          and not
    UNIVERSAL::isa($ref,'Class::AutoDB::SmartProxy')) ?  # allow for lists
    1 : 0;
}

# return true if $object is an inside object (AutoDB able)
sub is_inside {
  my ($self,$obj) = @_;
  return
    (ref($obj)                                             and
    UNIVERSAL::isa(ref($obj),'Class::AutoDB::SmartProxy')  and
    $obj->{__object_id})                                   ?
    1 : 0; 
}


# args will be presented as either an Class::AutoDB::Collection instance
# or as members of a Class::AutoClass::Args instance.
# return as an array ref of Collections
sub _normalize {
  my($args)=shift;
  my @collections;

  foreach my $item (@$args) {
    # collections as members of Class::AutoClass::Args instance
    if ( ref $item eq 'Class::AutoClass::Args' and scalar keys %{$item} ) {
      foreach my $collection ( @{$item->{collections}} ) {
        push @collections, $collection;
      }
    } else {
        push @collections, $item if ref($item) eq 'Class::AutoDB::Collection';
    }
  }
  return \@collections;
}

1;

__END__

=head1 NAME

Class::AutoDB::TypeMap;

=head1 SYNOPSIS

my $tm_init = new Class::AutoDB::TypeMap(-collections=>[$coll1, $coll2]);

my $type = $tm_init->type_of('friends','Person');

=head1 DESCRIPTION

A static class (only one instance is maintained) for keeping track of value => type mappings. 
Such mappings are created by the Class::AutoDb::Registry and held within Class::AutoDb::Collection instances. 
This class simply provides accessor methods to the mappings.

As it is likely that Class::AutoDB::Cache will be extended to the developer's particular needs, it is designed for subclassing.

=head1 KNOWN BUGS AND CAVEATS

This is still a work in progress.  

=head2 Bugs, Caveats, and ToDos

  TBD

=head1 AUTHOR - Nat Goodman, Chris Cavnor

Email ccavnor@systemsbiology.org

=head1 COPYRIGHT

Copyright (c) 2003 Institute for Systems Biology (ISB). All Rights Reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 APPENDIX

The rest of the documentation describes the methods.

=head2 Constructor

# Title   : new
# Usage   : $tm = Class::AutoDB::TypeMap->new or
            $tm = Class::AutoDB::TypeMap->new([-collections=>[$collection_0..$collection_n]);
# Function: creates global static reference to weak cache
# Returns : Class::AutoDB::TypeMap instance
# Args    : optionally takes an arrayref of collection objects
# Notes   : subclasses Class::WeakSingleton, so only one instance is maintained

# Title   : load
# Usage   : $tm->load($collection_object);
# Function: adds collections to the cache
# Returns : true if added, false otherwise
# Args    : a single collection object
# Notes   : 

# Title   : count
# Usage   : $tm->count;
# Function: find number of in-memory collections
# Returns : number of in-memory collections, or 0 if none
# Args    : none
# Notes   : 

# Title   : keys_for
# Usage   : $tm->keys_for('collection_name');
# Function: gets key,value pairs for collection_name
# Returns : hash or hash ref
# Args    : a collection name (string)
# Notes   : 

# Title   : type_of
# Usage   : $tm->value_of('key','collection_object');
# Function: fetches the type (string) of the given key within the given collection
# Returns : the value for the passed key (string)
# Args    : a collection name (string) and a key name (string)
# Notes   : throws exception when too few args
=cut