package Class::AutoDB::WeakCache;
use strict;
use base qw(Class::WeakSingleton);
use Storable qw(dclone);

# a weak cache for holding objects and their ref'd names. This is a static
# class, so only one instance is maintained.

sub cache {
  my($self,$target,$proxy)=@_;
  $self->throw('Class::AutoDB::WeakCache requires a lookup key (target) and an object instance to store') unless ($target && $proxy);
  $target = ref($target) || $target;
  return unless defined $proxy;
  # want a live reference of AutoDB, all others are deep copied for freezing
  if(ref($proxy) eq 'Class::AutoDB'){ $self->{storage}{$target} = $proxy }
  else { my $cloned = dclone($proxy); $self->{storage}{$target} = $cloned }
}
sub recall {
 my($self,$target)=@_;
 $target = ref($target) || $target;
 return $self->{storage}{$target};
}
sub exists {
 my($self,$target)=@_;
 $self->{storage}{$target} ? 1 : 0; 
}
sub remove {
 my($self,$target)=@_;
 delete $self->{storage}{$target};
}
sub dump {
 my $self=shift;
 return unless defined $self->{storage};
 $self->{storage};	
}
sub clean {
 my $self=shift;
 undef $self->{storage};
}

1;

__END__

=head1 NAME

Class::AutoDB::WeakCache;

=head1 SYNOPSIS

# global static reference to weak cache
my $wc = Class::AutoDB::WeakCache->instance();
$wc->cache($unique_id,$self);

# ...later (probably from another class instance):
$wc->recall($unique_id);


=head1 DESCRIPTION

A static dictionary for associating an object with a lookup key. Class::WeakCache holds a copy of
an object until Class::AutoDB is ready to persist it into a permanant data store.

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

 Title   : instance
 Usage   : $wc = Class::AutoDB::WeakCache->instance();
 Function: creates global static reference to weak cache
 Returns : Class::AutoDB::WeakCache instance
 Args    : none
 Notes   : subclasses Class::WeakSingleton
 
# Title   : instance
# Usage   : $wc = Class::AutoDB::WeakCache->instance();
# Function: creates global static reference to weak cache
# Returns : Class::AutoDB::WeakCache instance
# Args    : none
# Notes   : subclasses Class::WeakSingleton

#
# Title   : cache
# Usage   : $wc->cache($unique_id,$self);
# Function: takes a reference to an object and a lookup key and deep copies the object
#         : (AutoDB references are not copied) for freezing.
# Returns : the cached object
# Args    : string identifier, object
# Notes   : 

# Title   : exists
# Usage   : $wc->exists($unique_id);
# Function: find out if an object with identifier $unique_id has been cached
# Returns : 1 if exists, else 0
# Args    : string identifier
# Notes   : 

# Title   : recall
# Usage   : $wc->recall($unique_id);
# Function: retrieve the cached object (in the case of Class::AutoDB object)
#         : or a copy (snapshot when cache() is called) of the object
# Returns : see above
# Args    : string identifier
# Notes   : 

# Title   : dump
# Usage   : $wc->dump;
# Function: dumps the contents of the cache
# Returns : a hash ref of stored hashes or undef if none exist
# Args    : none
# Notes   : 

# Title   : remove
# Usage   : $wc->remove($unique_id);
# Function: removes the object pointed to by identifier from the cache
# Returns : the removed object
# Args    : string identifier
# Notes   :

# Title   : clean
# Usage   : $wc->clean;
# Function: resets the cache, removing all obects and their identifiers
# Returns : undef
# Args    : none
# Notes   :

=cut