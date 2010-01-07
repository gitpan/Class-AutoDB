use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize02;

# The testSerialize series tests Class::AutoDB::Serialize
# This test stores a series of objects with embedded objects
# for later fetch by its companion testSerialize1b.t

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

  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj=new testSerialize(object=>$obj1);
  store('object',$obj);
  
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->store;
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  store('object_list',$obj);
  
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->store;
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  store('object_hash',$obj);
  
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->store;
  my $obj=new testSerialize(object_list_list=>[[$obj1,$obj2,$obj3,$obj4]]);
  store('object_list_list',$obj);
  
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->store;
  my $obj=new testSerialize(object_list_hash=>[{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4}]);
  store('object_list_hash',$obj);
  
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->store;
  my $obj=new testSerialize(object_hash_hash=>{hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4}});
  store('object_hash_hash',$obj);
  
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->store;
  my $obj=new testSerialize(object_hash_list=>{list=>[$obj1,$obj2,$obj3,$obj4]});
  store('object_hash_list',$obj);
  
  my $obj1=new testSerialize(string=>'shared obj1'); $obj1->store;
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  store('object_shared',$obj);

  my $obj1=new testSerialize(string=>'shared obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'shared obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'shared obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'shared obj4'); $obj4->store;
  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  store('object_list_shared',$obj);
 
  my $obj1=new testSerialize(string=>'shared obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'shared obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'shared obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'shared obj4'); $obj4->store;
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  store('object_hash_shared',$obj);

  my $obj1=new testSerialize(string=>'shared obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'shared obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'shared obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'shared obj4'); $obj4->store;
  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  store('object_multi',$obj);

  my $obj=new testSerialize;
  $obj->{self_circular}=$obj;
  store('self_circular',$obj);
  
  my $obj=new testSerialize;
  $obj->{self_circular_shared1}=$obj;
  $obj->{self_circular_shared2}=$obj;
  store('self_circular_shared',$obj);
  
  my $obj=new testSerialize;
  $obj->{self_circular_list}=[$obj,$obj,$obj,$obj];
  store('self_circular_list',$obj);

  my $obj=new testSerialize;
  $obj->{self_circular_hash}={a=>$obj,b=>$obj,c=>$obj,d=>$obj};
  store('self_circular_hash',$obj);

  my $obj=new testSerialize(integer=>1234,
			    float=>12.34,
			    string=>'a string',
			    list=>[qw(a b c d)],
			    hash=>{a=>1,b=>2,c=>3,d=>4});
  $obj->{self_circular}=$obj;
  $obj->{self_circular_list}=[$obj,$obj,$obj,$obj];
  $obj->{self_circular_hash}={a=>$obj,b=>$obj,c=>$obj,d=>$obj};
  store('self_circular_multi',$obj);

  my $obj1=new testSerialize(string=>'shared obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'shared obj2'); $obj2->store;
  my $obj3=new testSerialize(string=>'shared obj3'); $obj3->store;
  my $obj4=new testSerialize(string=>'shared obj4'); $obj4->store;
  my $obj=new testSerialize(integer=>1234,
			    float=>12.34,
			    string=>'a string',
			    list=>[qw(a b c d)],
			    hash=>{a=>1,b=>2,c=>3,d=>4},
			    object_list=>[$obj1,$obj2,$obj3,$obj4],
			    object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  $obj->{self_circular}=$obj;
  $obj->{self_circular_list}=[$obj,$obj,$obj,$obj];
  $obj->{self_circular_hash}={a=>$obj,b=>$obj,c=>$obj,d=>$obj};
  store('very_multi',$obj);

  # set up to test 'class' method on Oids and real objects
  my $obj1=new testSerialize(string=>'obj1'); $obj1->store;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->store;
  my $obj=new testSerialize(object_list=>[$obj1,$obj2]);
  store('test_class_method',$obj);

  untie %oid;
}

done_testing();
