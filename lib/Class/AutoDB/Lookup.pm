package Class::AutoDB::Lookup;
use strict;
use base qw/Class::WeakSingleton/;

# this class stores keys value pairs in both directions, such that:
# k -> v, and
# v -> k
# this is done to facilitate lookup by either an object's address or its unique ID

sub new {
  my $self = shift;
  my %storage;
  return bless \%storage, $self;
}

sub remember {
  my $self = shift;
  my $uid = _getUID();
  $self->{storage}{$_[0]} = $uid;
  $self->{storage}{$uid} = $_[0];
  return $uid;
}
sub recall {
 my $self = shift;
 return $self->{storage}{$_[0]};
}
sub brainDump {
 my $self = shift;
 use Data::Dumper;
 return unless defined $self->{storage};
 %{$self->{storage}};	
}
sub brainWash {
 my $self = shift;
 undef $self->{storage};
}
sub _getUID {
 return substr($$.(time % rand(time)),1,9);
}

1;

__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::Cursor

=head1 SYNOPSIS

use Class::AutoDB::Lookup;

=head1 DESCRIPTION


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

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   : 

 Title   : remember
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   : 
 
 Title   : recall
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   :
 
 Title   : brainDump
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   : 
 
 Title   : brainWash
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   : 

 Title   : _getUID
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   : 

=cut
