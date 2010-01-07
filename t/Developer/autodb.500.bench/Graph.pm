package Graph;
use strict;
use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES %DEFAULTS @EXPORT %AUTODB);
use strict;

@AUTO_ATTRIBUTES=qw(name name2node name2edge);
%DEFAULTS=(nodes=>[],edges=>[],name2node=>{},name2edge=>{});
%AUTODB=(collection=>'Graph',keys=>qq(name string));
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

################################################################################
# Method below here are for making test graphs
################################################################################
use Hash::AutoHash::Args;

my %DEFAULT_ARGS=
  (CIRCUMFERENCE=>100,
   CONE_SIZE=>10,
   HEIGHT=>10,
   WIDTH=>10,
   ARITY=>2,
   DEPTH=>3,
   NODES=>100,
  );

sub binary_tree {shift->regular_tree(@_,-arity=>2)}
sub ternary_tree {shift->regular_tree(@_,-arity=>3)}

sub chain {
  my $chain=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($nodes)=get_args($args,qw(nodes));
  if ($nodes) {
    for (my $new=1; $new<$nodes; $new++) {
      $chain->add_edge($new-1,$new);
    }}
  $chain;
}
sub regular_tree {
  my $tree=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($depth,$arity,$root)=get_args($args,qw(depth arity root));
  defined $root or $root=0;
  $tree->add_node($root);
  if ($depth>0) {
    for (my $i=0; $i<$arity; $i++) {
      my $child="$root/$i";
      $tree->add_edge($root,$child);
      $tree->regular_tree(depth=>$depth-1,arity=>$arity,root=>$child);
    }
  }
  $tree;
}

sub star {
  my $star=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($nodes)=get_args($args,qw(nodes));
  if ($nodes) {
    my $center=0;
    for (my $point=1; $point<$nodes; $point++) {
      $star->add_edge($center,$point);
    }}
  $star
}
sub cycle {
  my $graph=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($nodes)=get_args($args,qw(nodes));
  # make simple cycle
  for (my $i=1; $i<$nodes; $i++) {
    $graph->add_edge($i-1,$i);
  }
  $graph->add_edge($nodes-1,0);
  $graph;
}
sub clique {
  my $graph=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($nodes)=get_args($args,qw(nodes));
  for (my $i=0; $i<$nodes-1; $i++) {
    for (my $j=$i+1; $j<$nodes; $j++) {
      $graph->add_edge($i,$j);
    }
  }
  $graph;
}
sub cone_graph {
  my $graph=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($cone_size)=get_args($args,qw(cone_size));
  # make $cone_size simple cycles of sizes 1..$cone_size
  for (my $i=0; $i<$cone_size; $i++) {
    my $circumference=$i+1;
    # make simple cycle
    for (my $j=1; $j<$circumference; $j++) {
      $graph->add_edge($i.'/'.($j-1),"$i/$j");
    }
    $graph->add_edge($i.'/'.($circumference-1),"$i/0");
  }
  # add edges between cycles
  for (my $i=0; $i<$cone_size-2; $i++) {
    for (my $j=$i+1; $j<$cone_size; $j++) {
      $graph->add_edge("$i/0","$j/0");
    }}
  $graph;
}
sub grid {
  my $graph=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($height,$width)=get_args($args,qw(height width));
  for (my $i=0; $i<$height; $i++) {
    for (my $j=0; $j<$width; $j++) {
      my $node=grid_node($i,$j);
      $graph->add_node($node);
      $graph->add_edge(grid_node($i-1,$j),$node) if $i>0; # down
      $graph->add_edge(grid_node($i,$j-1),$node) if $j>0; # right
    }}
  $graph;
}
sub torus {
  my $graph=shift;
  my $args=new Hash::AutoHash::Args(@_);
  my($height,$width)=get_args($args,qw(height width));
  for (my $i=0; $i<$height; $i++) {
    for (my $j=0; $j<$width; $j++) {
      my $node=grid_node($i,$j);
      $graph->add_node($node);
      $graph->add_edge(grid_node($i-1,$j),$node) if $i>0; # down
      $graph->add_edge(grid_node($i,$j-1),$node) if $j>0; # right
    }}
  # add wrapround edges, making grid a torus
  if ($width>1) {
    for (my $i=0; $i<$height; $i++) {
      $graph->add_edge(grid_node($i,$width-1),grid_node($i,0));
    }}
  if ($height>1) {
    for (my $j=0; $j<$width; $j++) {
      $graph->add_edge(grid_node($height-1,$j),grid_node(0,$j));
    }}
  $graph;
}
sub grid_node {my($i,$j)=@_; $j=$i unless defined $j; "$i/$j";}

# probably not needed with new Hash::AutoHash::Args
sub get_args {
  my $args=shift;
  my @args;
  for my $keyword (@_) {
    my $arg=$args->$keyword;
    defined $arg or $arg=$DEFAULT_ARGS{uc $keyword};
    push(@args,$arg);
  }
  wantarray? @args: $args[0];
}
*get_arg=\&get_args;

########################################
# represents one node of a graph
package Node;
use strict;
use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES %DEFAULTS);
use strict;

@AUTO_ATTRIBUTES=qw(name neighbors);
%DEFAULTS=(neighbors=>[]);
Class::AutoClass::declare;

sub add_neighbor {
  my($self,$neighbor)=@_;
  push(@{$self->neighbors},$neighbor) unless $self==$neighbor;
}

########################################
# represents one edge of a graph
package Edge;
use strict;
use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES %DEFAULTS);
# use Node;

@AUTO_ATTRIBUTES=qw(nodes);
%DEFAULTS=(nodes=>[]);
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

