package Class::AutoDB::Registration;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

  @AUTO_ATTRIBUTES=qw(class _collection _keys _skip _auto_get);
  @OTHER_ATTRIBUTES=qw(collection collections keys skip auto_get);
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}

sub collections {
  my $self=shift;
  my $result;
  if (@_) {
    'ARRAY' eq ref $_[0]? $self->_collection($_[0]): $self->_collection([$_[0]]);
    $result=$self->_collection;
  }
  $result= @_? $self->_collection([_flatten(@_)]): $self->_collection;
  ($result && wantarray)? @$result: $result;
}
sub collection {
  my $self=shift;
  my $result=$self->collections(@_);
  ($result && wantarray)? @$result: $result->[0];
}
sub keys {
  my $self=shift;
  my $result;
  if (@_) {
    my $arg=shift;
    if (!defined $arg) {
      $result=undef;
    } elsif ('ARRAY' eq ref $arg) {
      map {$result->{$_}='string'} @$arg;
    } else {
      my @args=split(/\s*,\s*/,$arg); # split stiring at commas
      for my $arg (@args) {
	$arg=~s/^\s*(.*?)\s*$/$1/;
	$arg=~s/\s+/ /g;
	my($key,$type)=($arg=~/^\W*(\w+)\W+(.*)/);
	$result->{$key}=$type;
      }
    }
    $self->_keys($result);
  } else {
    $result=$self->_keys;
  }
  ($result && wantarray)? %$result: $result;
}
sub skip {
  my $self=shift;
  my $result= @_? $self->_skip($_[0]): $self->_skip;
  ($result && wantarray)? @$result: $result;
}
sub auto_get {
  my $self=shift;
  my $result= @_? $self->_auto_get($_[0]): $self->_auto_get;
  ($result && wantarray)? @$result: $result;
}

sub _flatten {map {'ARRAY' eq ref($_) ? _flatten(@$_): $_} @_;}
  
1;

__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::Registration - One registration for Class::AutoDB::Registry

=head1 SYNOPSIS

This is a helper class for 
Class::AutoDB::Registration which represents one entry in registry.

  use Class::AutoDB::Registration;
  my $registration=new Class::AutoDB::Registration(
               -class=>'Class::Person',
               -collection=>'Person',
               -keys=>qq(name string, sex string, significant_other object, friends list(object)),
               -skip=>[qw(age)],
               -auto_get=>[qw(significant_other)]);
  my $collection=$registration->collection; 
  my $class=$registration->class; 
  my $keys=$registration->keys;	# returns hash of key=>type pairs
  my $skip=>$registration->skip;
  my $auto_get=>$registration->auto_get;

=head1 DESCRIPTION

This class represents essentially raw registration information
submitted via the 'register' method of
Class::AutoDB::Registry.  This class parses the 'keys'
string, but does not verify that attribute names and data types are
valid.

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

 Usage   : $registration=new Class::AutoDB::Registration(
               -class=>'Class::Person',
               -collection=>'Person',
               -keys=>qq(name string, sex string, significant_other object, friends list(object)),
               -skip=>[qw(age)],
               -auto_get=>[qw(significant_other)]);
 Function: Create registration object
 Returns : New Class::AutoDB::Registration object
 Args    :  -class	name of class being registered
            -collection	name of collection being registered
                        or ARRAY of names
           -collections synonym for -collection
           -keys	search keys for collection.
                        Can be string of comma separated attribute and data type pairs,
                        or ARRAY of attributes (in which case the type is assumed to be
                        'string')
           -skip	ARRAY of attributes that should not be stored
           -auto_get	ARRAY of attributes that should be automatically
                        retrieved when this object is retrieved

=head2 Simple attributes

These are methods for getting and setting the values of simple
attributes. Each of these can be set in the argument list to new, if
desired.  Some of these should be read-only (more precisely, should
only be written by code internal to the object), but this is not
enforced. We assume, Perl-style, that programmers will behave nicely
and not complain too loudly if the software lets them do something
stupid.

Methods have the same name as the attribute.  To get the value of
attribute xxx, just say $xxx=$object->xxx; To set it, say
$object->xxx($new_value); To clear it, say $object->xxx(undef);

 Attr    : class
 Function: name of class that was registered
 Access  : read-write

 Attr    : collection
 Function: name of collection that registered
 Returns : In scalar context, the name (if there's just one)
           or the first name (if there are several)
           In array context, list of names
 Access  : read-write

 Attr    : collections
 Function: synonym for collection with slightly different return types
 Returns : In scalar context, ARRAY ref of names
           In array context, list of names
 Access  : read-write

 Attr    : skip
 Function: ARRAY of skipped attributes
 Returns : In scalar context, ARRAY ref of 
           In array context, list of names
 Access  : read-write

 Attr    : auto_get
 Function: ARRAY of auto_get attributes
 Returns : In scalar context, ARRAY ref of 
           In array context, list of names
 Access  : read-write

=head2 keys

 Title   : keys
 Usage   : %keys=$registration->keys
           -- OR --
           $keys=$registration->keys
 Function: Returns keys that were registered and their data types
 Args    : None
 Returns : hash or HASH ref of key=>type pairs

The 'keys' parameter consists of attribute, data type pairs.  Each
attribute is generally an attribute defined in the AutoClass
@AUTO_ATTRIBUTES or @OTHER_ATTRIBUTES variables.  (Technically, it's
the name of a method that can be called with no arguments.) The value
of an attribute must be a scalar, an object reference, or an ARRAY (or
list) of such values.) 

The data type can be 'string', 'integer', 'float', 'object', any legal
MySQL column type, or the phrase list(<data type>), eg,
'list(integer)'.

NB: At present, only our special data types ('string', 'integer',
'float', 'object') are supported. These can be abbreviated.

The 'keys' parameter can also be an array of attribute names, eg,

    -keys=>[qw(name sex)]

in which case the data type of each attribute is assumed to be
'string'.  This works in many cases even if the data is really
numeric as discussed in the Persistence Model section.

The types 'object' and 'list(object)' only work for objects whose
persistence is managed by AutoDB.

=cut
