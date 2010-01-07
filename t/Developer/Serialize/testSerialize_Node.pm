package testSerialize_Node;

# represents one node of a graph

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Serialize;
@ISA=qw(Class::AutoClass Class::AutoDB::Serialize); # AutoClass must be first!!;

@AUTO_ATTRIBUTES=qw(id neighbors);
%DEFAULTS=(neighbors=>[]);
Class::AutoClass::declare;

sub add_neighbor {
  my($self,$neighbor)=@_;
  push(@{$self->neighbors},$neighbor) unless $self==$neighbor;
}
# to force fetch of embedded Oids in tests
sub nop {undef;}
use overload
  fallback => 'TRUE';

1;
