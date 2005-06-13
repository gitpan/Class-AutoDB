use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize04;

# The testSerialize series tests Class::AutoDB::Serialize
# This test stores a series of objects with embedded objects that are
# not decendants of Class::AutoDB:Serialize
# for later fetch by its companion test

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

  my $obj1=new testNonSerialize(string=>'obj1');
  my $obj=new testSerialize(object=>$obj1);
  store('object',$obj);
  
  my $obj1=new testNonSerialize(string=>'obj1');
  my $obj2=new testNonSerialize(string=>'obj2');
  my $obj3=new testNonSerialize(string=>'obj3');
  my $obj4=new testNonSerialize(string=>'obj4');
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  store('object_list',$obj);
  
  my $obj1=new testNonSerialize(string=>'obj1');
  my $obj2=new testNonSerialize(string=>'obj2');
  my $obj3=new testNonSerialize(string=>'obj3');
  my $obj4=new testNonSerialize(string=>'obj4');
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  store('object_hash',$obj);
  
  my $obj1=new testNonSerialize(string=>'shared obj1');
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  store('object_shared',$obj);
  
  my $obj1=new testNonSerialize(string=>'shared obj1');
  my $obj2=new testNonSerialize(string=>'shared obj2');
  my $obj3=new testNonSerialize(string=>'shared obj3');
  my $obj4=new testNonSerialize(string=>'shared obj4');
  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  store('object_list_shared',$obj);
 
  my $obj1=new testNonSerialize(string=>'shared obj1');
  my $obj2=new testNonSerialize(string=>'shared obj2');
  my $obj3=new testNonSerialize(string=>'shared obj3');
  my $obj4=new testNonSerialize(string=>'shared obj4');
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  store('object_hash_shared',$obj);

  my $obj1=new testNonSerialize(string=>'shared obj1');
  my $obj2=new testNonSerialize(string=>'shared obj2');
  my $obj3=new testNonSerialize(string=>'shared obj3');
  my $obj4=new testNonSerialize(string=>'shared obj4');
  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  store('object_multi',$obj);

  my $obj1=new testNonSerialize(string=>'self_circular obj1');
  $obj1->{self_circular}=$obj1;
  my $obj=new testSerialize(object=>$obj1);
  store('circular_shared',$obj);
  
  my $obj1=new testNonSerialize(string=>'self_circular_shared obj1');
  $obj1->{self_circular_shared1}=$obj1;
  $obj1->{self_circular_shared2}=$obj1;
  my $obj=new testSerialize(object=>$obj1);
  store('self_circular_shared',$obj);
  
  my $obj1=new testNonSerialize(string=>'self_circular_list obj1');
  $obj1->{self_circular_list}=[$obj1,$obj1,$obj1,$obj1];
  my $obj=new testSerialize(object=>$obj1);
  store('self_circular_list',$obj);

  my $obj1=new testNonSerialize(string=>'self_circular_hash obj1');
  $obj1->{self_circular_hash}={a=>$obj1,b=>$obj1,c=>$obj1,d=>$obj1};
  my $obj=new testSerialize(object=>$obj1);
  store('self_circular_hash',$obj);

  my $obj1=new testNonSerialize(integer=>1234,
				float=>12.34,
				string=>'a string',
				list=>[qw(a b c d)],
				hash=>{a=>1,b=>2,c=>3,d=>4});
  $obj1->{self_circular}=$obj1;
  $obj1->{self_circular_list}=[$obj1,$obj1,$obj1,$obj1];
  $obj1->{self_circular_hash}={a=>$obj1,b=>$obj1,c=>$obj1,d=>$obj1};
  my $obj=new testSerialize(object=>$obj1);
  store('self_circular_multi',$obj);

  my $obj1=new testNonSerialize(string=>'shared obj1');
  my $obj2=new testNonSerialize(string=>'shared obj2');
  my $obj3=new testNonSerialize(string=>'shared obj3');
  my $obj4=new testNonSerialize(string=>'shared obj4');
  my $obj0=new testNonSerialize(integer=>1234,
				float=>12.34,
				string=>'a string',
				list=>[qw(a b c d)],
				hash=>{a=>1,b=>2,c=>3,d=>4},
				object_list=>[$obj1,$obj2,$obj3,$obj4],
				object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  $obj0->{self_circular}=$obj0;
  $obj0->{self_circular_list}=[$obj0,$obj0,$obj0,$obj0];
  $obj0->{self_circular_hash}={a=>$obj0,b=>$obj0,c=>$obj0,d=>$obj0};
  my $obj=new testSerialize(object=>$obj1);
  store('very_multi',$obj);

  untie %oid;
}

