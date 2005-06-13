use Test::Harness;
use strict;

# Driver for Class::AutoDB::Serialize tests
# Note: testSerialize06a.multistore.t is deliberately being run several time
# because it tests repeated storage of the same objects

my @test_files=
  qw(testSerialize00.setup.t
     testSerialize01a.simple.t
     testSerialize01b.simple.t
     testSerialize02a.object.t
     testSerialize02b.object.t
     testSerialize03a.object.t
     testSerialize03b.object.t
     testSerialize04a.object.non.t
     testSerialize04b.object.non.t
     testSerialize05a.object.non.t
     testSerialize05b.object.non.t
     testSerialize06a.multistore.t
     testSerialize06a.multistore.t
     testSerialize06a.multistore.t
     testSerialize10a.graph.t
     testSerialize10b.graph.t
     testSerialize11a.big.t
     testSerialize11b.big.t
     testSerialize12a.person.t
     testSerialize12b.person.t
     testSerialize13a.foobar.t
     testSerialize13b.foobar.t
);

$Test::Harness::switches='';	# turn off -w
runtests(@test_files);
