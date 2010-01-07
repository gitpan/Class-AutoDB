########################################
# benchmark graphs using our homegrown graph implementation
########################################
use t::lib;
use strict;
use Benchmark::Timer;
use Test::More;
use Graph;
use Class::AutoDB;
use Scalar::Util qw(refaddr);
use Data::Dumper;

my $what=shift @ARGV || 'freeze';

# my $timer=Benchmark::Timer->new(skip=>1,confidence=>95,error=>5);
my $dumper=new Data::Dumper([undef],['thaw'])->Purity(1)->Indent(1);
my $timer;
my $autodb;

my $GLOBALS=Class::AutoDB::Globals->instance();
my $OID2OBJ=$GLOBALS->oid2obj;
my $OBJ2OID=$GLOBALS->obj2oid;

$what=~/^f/i and do {
  $timer=Benchmark::Timer->new(skip=>5);
  $autodb=new Class::AutoDB(database=>'test',create=>1);
  do_freeze('chain');
  do_freeze('star');
  do_freeze('binary_tree',-depth=>5);
  do_freeze('ternary_tree',-depth=>5);
  do_freeze('cycle');
  do_freeze('clique',-nodes=>20);
  do_freeze('cone_graph');
  do_freeze('grid');
  do_freeze('torus');
  emit_timer();
  # print $timer->reports;
  pass('end of freeze test');
};

$what=~/^t/i and do {
  $timer=Benchmark::Timer->new(skip=>5);
  $autodb=new Class::AutoDB(database=>'test');
  do_thaw('chain');
  do_thaw('star');
  do_thaw('binary_tree',-depth=>5);
  do_thaw('ternary_tree',-depth=>5);
  do_thaw('cycle');
  do_thaw('clique',-nodes=>20);
  do_thaw('cone_graph');
  do_thaw('grid');
  do_thaw('torus');
  emit_timer();
  pass('end of thaw test');
};
done_testing();

sub do_freeze {
  my $name=shift;
  my $graph=new Graph(name=>$name);
  $graph->$name(@_);
  # hack so that each put stores a new object
  my $refaddr=refaddr $graph;
  my $oid=$OBJ2OID->{$refaddr};
  delete $OID2OBJ->{$oid};
  my $oid=int rand 1<<30;	# 2**30;
  $OBJ2OID->{$refaddr}=$oid;
  $OID2OBJ->{$oid}=$graph;

  print join(' ',$graph->name,scalar @{$graph->nodes},'nodes,',scalar @{$graph->edges},'edges')
    ,"\n";
  for (1..15) {
    freeze($graph,'xs');
  } 
  for (1..15) {
    freeze($graph,'autodb');
  }  
  for (1..10) {
    freeze($graph,'perl');
  }
}
sub freeze {
  my($graph,$imp)=@_;
  local $SIG{__WARN__}=sub {warn @_ unless $_[0]=~/^Deep recursion/;};
  local $DB::deep=0;
  my $tag=$graph->name." $imp";
  $timer->start($tag);
  if ($imp=~/autodb/i) {
#     # hack so that each put stores a new object
#     my $refaddr=refaddr $graph;
#     my $oid=$OBJ2OID->{$refaddr};
#     delete $OID2OBJ->{$oid};
#     $OBJ2OID->{refaddr $graph}=++$oid;
#     $OID2OBJ->{$oid}=$graph;
    $autodb->put($graph);
   } else {
    $dumper->Reset;
    $dumper->Useperl($imp=~/perl/i||0);
    my $freeze=$dumper->Values([$graph])->Dump;
  }
  $timer->stop($tag);
}
sub do_thaw {
  my $name=shift;
  my $graph=new Graph(name=>$name);
  $graph->$name(@_);
  print join(' ',$graph->name,scalar @{$graph->nodes},'nodes,',scalar @{$graph->edges},'edges')
    ,"\n";

  local $SIG{__WARN__}=sub {warn @_ unless $_[0]=~/^Deep recursion/;};
  local $DB::deep=0;
  $dumper->Reset;
  $dumper->Useperl(0);
  my $freeze=$dumper->Values([$graph])->Dump;
  for (1..10) {
    thaw($freeze,$name,'xs');
  } 
  for (1..15) {
    thaw($freeze,$name,'autodb');
  }  
#   $dumper->Reset;
#   $dumper->Useperl(1);
#   my $freeze=$dumper->Values([$graph])->Dump;
  for (1..10) {
     thaw($freeze,$name,'perl');
   }
}
sub thaw {
  my($freeze,$name,$imp)=@_;
  local $SIG{__WARN__}=sub {warn @_ unless $_[0]=~/^Deep recursion/;};
  local $DB::deep=0;
  my $tag=$name." $imp";
  $timer->start($tag);
  if ($imp=~/autodb/i) {
     my($graph)=$autodb->get(collection=>'Graph',name=>$name);
     # hack so that each get thaws a new object
     my $refaddr=refaddr $graph;
     my $oid=$OBJ2OID->{$refaddr};
     delete $OID2OBJ->{$oid};
     delete $OBJ2OID->{$refaddr};
  } else {
     my $thaw;			# variable used in $dumper
     eval $freeze;		# sets $thaw
   }
  $timer->stop($tag);
}

sub emit_timer {
  my @results=$timer->results;
#  while(my($tag,$time_autodb,$tag,$time_xs,$tag,$time_perl)=splice(@results,0,6)) {
  while(my($tag,$time_xs,$tag,$time_autodb,$tag,$time_perl)=splice(@results,0,6)) {
    my($name)=$tag=~/^(\w+)/;
    note join("\t",sprintf("%16s","$name:"),ms($time_xs),ms($time_autodb),ms($time_perl)),"\n";
  }
}
sub ms {
  my $time=shift;
  $time*=1000;			# convert to ms
#  sprintf("%3i",int($time)).'ms';
  sprintf("%3i",$time).'ms';
}
