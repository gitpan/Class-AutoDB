package Class::AutoDB::StoreCache;
use strict;
use base qw(Class::AutoDB::Cache);

# A static class (only one instance is maintained) for holding actively used objects

sub cache {
  my $self=shift;
  my($key,$store)=@_;
  $self->throw('Class::AutoDB::StoreCache::cache requires a lookup key and an object instance to store') unless ($key && $store);
  $self->SUPER::cache(@_);
}

1;

__END__

=head1 NAME

Class::AutoDB::StoreCache;

=head1 SYNOPSIS

# global static reference to weak cache
my $sc = Class::AutoDB::StoreCache->instance();
$wc->cache($unique_id,$self);

# ...later (probably from another class instance):
$sc->recall($unique_id);


=head1 DESCRIPTION

see Class::AutoDB::Cache - overridden methods are documented here

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

#
# Title   : cache
# Usage   : $wc->cache($unique_id,$self);
# Function: takes a reference to an object and a lookup key.
# Returns : the cached object
# Args    : string identifier, object
# Notes   : throws exception if no key, object to store are given

=cut