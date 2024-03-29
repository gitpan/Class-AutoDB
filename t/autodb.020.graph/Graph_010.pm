package Graph_010;
use strict;
use base qw(HasID);
use vars qw(@AUTO_ATTRIBUTES %DEFAULTS %AUTODB @EXPORT);
use strict;

@AUTO_ATTRIBUTES=qw(name name2node name2edge);
%DEFAULTS=(nodes=>[],edges=>[],name2node=>{},name2edge=>{});
%AUTODB=(-collection=>'Graph_010',-keys=>qq(id integer, name string),
	 transients=>qq(name2node name2edge));
Class::AutoClass::declare;

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my $nodes=$args->nodes;
  defined($nodes) and $self->add_nodes(@$nodes);
  my $edges=$args->edges;
  defined($edges) and $self->add_edges(@$edges);
}
sub nodes {
  my $self=shift;
  my $nodes=@_? $self->{nodes}=$_[0]: $self->{nodes};
  wantarray? @$nodes: $nodes;
}
sub edges {
  my $self=shift;
  my $edges=@_? $self->{edges}=$_[0]: $self->{edges};
  wantarray? @$edges: $edges;
}
sub neighbors {
  my($self,$source)=@_;
  $source->neighbors;
}
sub add_nodes {
  my($self,@names)=@_;
  my $nodes=$self->{nodes};
  my $name2node=$self->name2node || $self->_init_name2node;
  for my $name (@names) {
    next if defined $name2node->{$name};
    my $node=new Node(name=>$name);
    push(@$nodes,$node);
    $name2node->{$name}=$node;
  }
}
*add_node=\&add_nodes;

sub add_edges {
  my $self=shift @_;
  my $edges=$self->{edges};
  my $name2edge=$self->name2edge || $self->_init_name2edge;
  while (@_) {
    my($m,$n);
    if ('ARRAY' eq ref $_[0]) {
      ($m,$n)=@$_[0];
    } else {
      ($m,$n)=(shift,shift);
    }
    last unless defined $m && defined $n;
    $m=$m->name if 'Node' eq ref $m;
    $n=$n->name if 'Node' eq ref $n;
    ($m,$n)=($n,$m) if $n lt $m;
    next if defined $name2edge->{Edge->name($m,$n)};
    $self->add_nodes($m,$n);
    my($node_m,$node_n)=map {$self->name2node->{$_}} ($m,$n);
    my $edge=new Edge(-nodes=>[$node_m,$node_n]);
    $node_m->add_neighbor($node_n);
    $node_n->add_neighbor($node_m);
    push(@$edges,$edge);
    $name2edge->{$edge->name}=$edge;
  }
}
*add_edge=\&add_edges;

sub dfs {
  my($graph,$start)=@_;
  $start or $start=$graph->nodes->[0];
  my $past={};
  my $present;
  my $future=[$start];
  my $results=[];
  while (@$future) {
    $present=shift @$future;
    unless($past->{$present}) { # this is a new node
      $past->{$present}=1;
      push(@$results,$present);
      unshift(@$future,@{$graph->neighbors($present)});
    }
  }
  wantarray? @$results: $results;
}
sub init_transients {
  my $self=shift;
  $self->_init_name2node;
  $self->_init_name2edge;
}
# name2node is transient. this method recomputes it
sub _init_name2node {
  my $self=shift;
  my @nodes=$self->nodes;
  my $name2node=$self->{name2node}={};
  map {$name2node->{$_->name}=$_} @nodes;
}
# name2edge is transient. this method recomputes it
sub _init_name2edge {
  my $self=shift;
  my @edges=$self->edges;
  my $name2edge=$self->{name2edge}={};
  map {$name2edge->{$_->name}=$_} @edges;
}

########################################
# represents one node of a graph
package Node;
use base qw(HasID);
use vars qw(@AUTO_ATTRIBUTES %DEFAULTS %AUTODB);
use strict;

@AUTO_ATTRIBUTES=qw(name neighbors);
%DEFAULTS=(neighbors=>[]);
%AUTODB=1;
Class::AutoClass::declare;

sub add_neighbor {
  my($self,$neighbor)=@_;
  push(@{$self->neighbors},$neighbor) unless $self==$neighbor;
}

########################################
# represents one edge of a graph
package Edge;
use base qw(HasID);
use vars qw(@AUTO_ATTRIBUTES %DEFAULTS %AUTODB);
# use Node;

@AUTO_ATTRIBUTES=qw(nodes);
%DEFAULTS=(nodes=>[]);
%AUTODB=1;
Class::AutoClass::declare;

sub _init_self {
  my($self,$class,$args)=@_;
  # return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my $nodes=$self->nodes;
  my($m,$n)=@$nodes;
  $self->nodes([$n,$m]) if defined $m && defined $n && $n->name lt $m->name;
  my($mname,$nname)=map {$_->name} @{$self->nodes};
  $self->{name}="$mname<->$nname";
}
# spit out "m<->n". 
# can be called as object or class method. as class method, args should be node names
sub name {
  my $self=shift;
  my $name=ref $self? (@_? $self->{name}=$_[0]: $self->{name}): join('<->',@_);
  # $name
}
1;

