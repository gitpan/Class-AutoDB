package Class::AutoDB::Cache;
use strict;
use base qw(Class::AutoClass Class::WeakSingleton);

# A static class (only one instance is maintained, it is "weak") for caching things.

sub cache {
  my($self,$key,$store)=@_;
  $key = ref($key) || $key;
  return unless defined $store;
  $self->{storage}{$key} = $store if $key;
}
sub recall {
 my($self,$key)=@_;
 $key = ref($key) || $key;
 return $self->{storage}{$key};
}
sub exists {
 my($self,$key)=@_;
 exists $self->{storage}{$key} ? 1 : 0;
}
sub remove {
 my($self,$key)=@_;
 delete $self->{storage}{$key};
}
sub count {
 my $self=shift;
 return scalar keys %{$self->{storage}} || 0;
}
sub dump {
 my $self=shift;
 return undef unless defined $self->{storage};
 return $self->{storage};	
}
sub clean {
 my $self=shift;
 undef $self->{storage};
}

1;

__END__

=head1 NAME

Class::AutoDB::Cache;

=head1 SYNOPSIS

# global static reference to weak cache
my $wc = Class::AutoDB::Cache->instance();
$wc->cache($unique_id,$self);

# ...later (probably from another class instance):
$wc->recall($unique_id);


=head1 DESCRIPTION

A static dictionary for associating an object with a lookup key. Class::AutoDB::Cache holds a copy of
an object until Class::AutoDB is ready to persist it into a permanant data store.

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

 Title   : instance
 Usage   : $wc = Class::AutoDB::Cache->instance();
 Function: creates global static reference to weak cache
 Returns : Class::AutoDB::Cache instance
 Args    : none
 Notes   : subclasses Class::WeakSingleton

#
# Title   : cache
# Usage   : $wc->cache($unique_id,$self);
# Function: takes a reference to an object and a lookup key.
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
# Function: retrieve the cached object.
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