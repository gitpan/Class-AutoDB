package testSerialize_Edge;

# represents one edge of a graph

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Serialize;
use testSerialize_Node;
@ISA=qw(Class::AutoClass Class::AutoDB::Serialize); # AutoClass must be first!!;

@AUTO_ATTRIBUTES=qw(label nodes);
%DEFAULTS=(nodes=>[]);
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my $nodes=$self->nodes;
  my($m,$n)=@$nodes;
  $self->nodes([$n,$m]) if defined $m && defined $n && $n->id lt $m->id;
}
# to force fetch of embedded Oids in tests
sub nop {undef;}

1;
