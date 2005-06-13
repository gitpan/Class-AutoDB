use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use YAML;
use Class::AutoDB::Serialize;
use testSerialize_Graph;

# The testSerialize series tests Class::AutoDB::Serialize
# This test fetched a series of objects  with embedded objects
# stored by its companion testSerialize1a.t

SKIP: {
  # make sure databases exist
  my $dbh=DBI->connect('dbi:mysql:database=test');
  skip "! Cannot connect to database: ".$dbh->errstr."\n".
    "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
      if $dbh->err;
  my %oid;
  my $tie=tie(%oid, 'SDBM_File', 'testSerialize.sdbm', O_RDWR, 0666);
  skip "! Cannot open SDBM file 'testSerialize.sdbm': ".$!."\n".
    "These tests require an SDBM file named 'testSerialize.sdbm'.  The user running the test must have permission to read and write this file."
      unless $tie;

  Class::AutoDB::Serialize->dbh($dbh);

  sub fetch_n_test {
    my($key,$obj)=@_;
    my $graph=Class::AutoDB::Serialize->fetch($oid{$key});
    $graph->dfs;		 # touches all nodes
    map {$_->nop} $graph->edges; # touch all edges
    is(Dump($obj),Dump($graph),$key);
  }
#    for my $value (values %$db_obj) {
#      if (UNIVERSAL::isa($value,'Class::AutoDB::Oid')) {
#	fetch($value);
#      } elsif ('ARRAY' eq ref $value) {
#	map {fetch($_)} @$value;
#      } elsif ('HASH' eq ref $value) {
#	map {fetch($_)} values %$value;
#      }
#    }
#    is(Dump($obj),Dump($db_obj),$key);
#  }
#  sub fetch {
#    my($db_obj)=@_;
#    return unless UNIVERSAL::isa($db_obj,'Class::AutoDB::Oid');
#    $db_obj->nop;		# force fetch
#    while(my($key,$value)=each %$db_obj) {
#      if (UNIVERSAL::isa($value,'Class::AutoDB::Oid')) {
#	fetch($value);
#      }}}
  
  my $graph=testSerialize_Graph::chain();
  fetch_n_test('chain',$graph);

  my $graph=testSerialize_Graph::star();
  fetch_n_test('star',$graph);

  my $graph=testSerialize_Graph::binary_tree(-depth=>5);
  fetch_n_test('binary_tree',$graph);

  my $graph=testSerialize_Graph::ternary_tree(-depth=>5);
  fetch_n_test('ternary_tree',$graph);

  my $graph=testSerialize_Graph::cycle();
  fetch_n_test('cycle',$graph);

  my $graph=testSerialize_Graph::clique(-nodes=>20);
  fetch_n_test('clique',$graph);

  my $graph=testSerialize_Graph::cone_graph();
  fetch_n_test('cone_graph',$graph);

  my $graph=testSerialize_Graph::grid();
  fetch_n_test('grid',$graph); 

  my $graph=testSerialize_Graph::torus();
  fetch_n_test('torus',$graph); 

  untie %oid;
}
1;
