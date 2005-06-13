use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize_Graph;

# The testSerialize series tests Class::AutoDB::Serialize
# This test creates and stores graphs for later fetch by 
# its companion testSerialize1b.t
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

  sub store {
    my($key,$obj)=@_;
    $oid{$key}=$obj->oid;
    $obj->store;
    ok(1,$key);
  }

  my $graph=testSerialize_Graph::chain();
  store('chain',$graph);

  my $graph=testSerialize_Graph::star();
  store('star',$graph);

  my $graph=testSerialize_Graph::binary_tree(-depth=>5);
  store('binary_tree',$graph);

  my $graph=testSerialize_Graph::ternary_tree(-depth=>5);
  store('ternary_tree',$graph);

  my $graph=testSerialize_Graph::cycle();
  store('cycle',$graph);

  my $graph=testSerialize_Graph::clique(-nodes=>20);
  store('clique',$graph);

  my $graph=testSerialize_Graph::cone_graph();
  store('cone_graph',$graph);

  my $graph=testSerialize_Graph::grid();
  store('grid',$graph); 

  my $graph=testSerialize_Graph::torus();
  store('torus',$graph); 

 untie %oid;
}  



