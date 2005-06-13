package Class::AutoDB::Registration;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Class::AutoClass;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

@AUTO_ATTRIBUTES=qw(class _collection _keys _transients _auto_gets);
@OTHER_ATTRIBUTES=qw(collection collections keys transients auto_gets);
%SYNONYMS=();
%DEFAULTS=(_keys=>{});
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}

sub collections {
  my $self=shift;
  my $result;
  $result=@_? $self->_collection(_raise(@_)): $self->_collection;
  $result or $result=[];
  wantarray? @$result: $result;
}
sub collection {
  my $self=shift;
  my $result=$self->collections(@_);
  $result or $result=[];
  wantarray? @$result: $result->[0];
}
sub keys {
  my $self=shift;
  my $result={};
  if (@_) {
    my $arg=shift;
    if (!defined $arg) {
      $result={};
    } elsif ('ARRAY' eq ref $arg) {
      map {$result->{$_}='string'} @$arg;
    } else {
      my @args=split(/\s*,\s*/,$arg); # split striing at commas
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
  wantarray? %$result: $result;
}
sub transients {
  my $self=shift;
  my $result=@_? $self->_transients($_[0]): $self->_transients;
  $result or $result=[];
  wantarray? @$result: $result;
}
sub auto_gets {
  my $self=shift;
  my $result= @_? $self->_auto_gets($_[0]): $self->_auto_gets;
  $result or $result=[];
  wantarray? @$result: $result;
}

sub _raise {
  my @args=grep {defined $_} @_;
  return undef unless @args;
  [map {'ARRAY' eq ref $_? @$_: $_} @args];
}
  
1;

__END__

=head1 NAME

Class::AutoDB::Registration - One registration for
Class::AutoDB::Registry

=head1 SYNOPSIS

This is a helper class for Class::AutoDB::Registry which represents one
entry in a registry.

 use Class::AutoDB::Registration;
 my $registration=new Class::AutoDB::Registration
   (-class=>'Class::Person',
    -collection=>'Person',
    -keys=>qq(name string, dob integer, significant_other object, 
              friends list(object)),
    -transients=>[qw(age)],
    -auto_gets=>[qw(significant_other)]);
 
 # Set the object's attributes
 my $collection=$registration->collection;
 my $class=$registration->class;
 my $keys=$registration->keys;
 my $transients=>$registration->transients;
 my $auto_gets=>$registration->auto_gets;

=head1 DESCRIPTION

This class represents essentially raw registration information
submitted via the 'register' method of Class::AutoDB::Registry. This
class parses the 'keys' parameter, but does not verify that attribute
names and data types are valid. This class I<does not talk to the
database>.

The 'keys' parameter consists of attribute, data type pairs, or can
also be an ARRAY ref of attribute names. In the latter case the data
type of each attribute is assumed to be 'string'.

=head1 BUGS and WISH-LIST

[none]

=head1 METHODS and FUNCTIONS - Initialization

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Registration.html#methods_and_functions>

=cut
