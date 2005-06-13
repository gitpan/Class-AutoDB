use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use YAML;
use Class::AutoDB::Serialize;
use testSerialize02;

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

  my %fetch_seen;
  sub fetch_n_test {
    my($key,$obj)=@_;
    my $db_obj=Class::AutoDB::Serialize->fetch($oid{$key});
    %fetch_seen=();
    fetch($db_obj);
    is(Dump($obj),Dump($db_obj),$key);
  }
  sub fetch {
    my($value)=@_;
    return if $fetch_seen{$value};
    $fetch_seen{$value}=$value;
    if (UNIVERSAL::isa($value,'Class::AutoDB::Oid')) {
      $value->nop;		# force fetch
    }
    return unless ref $value;
    if ('ARRAY' eq ref $value) {
      map {fetch($_)} @$value;
    } elsif (UNIVERSAL::isa($value,'HASH')) {
      map {fetch($_)} values %$value;
    }
  }

  my $obj1=new testSerialize(string=>'obj1');
  my $obj=new testSerialize(object=>$obj1);
  fetch_n_test('object',$obj);
  
  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test('object_list',$obj);
  
  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('object_hash',$obj);
  
  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');
  my $obj=new testSerialize(object_list_list=>[[$obj1,$obj2,$obj3,$obj4]]);
  fetch_n_test('object_list_list',$obj);

  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');
  my $obj=new testSerialize(object_list_hash=>[{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4}]);
  fetch_n_test('object_list_hash',$obj);
  
  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');
  my $obj=new testSerialize(object_hash_hash=>{hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4}});
  fetch_n_test('object_hash_hash',$obj);
  
  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');
  my $obj=new testSerialize(object_hash_list=>{list=>[$obj1,$obj2,$obj3,$obj4]});
  fetch_n_test('object_hash_list',$obj);
  
  my $obj1=new testSerialize(string=>'shared obj1');
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  fetch_n_test('object_shared',$obj);

  my $obj1=new testSerialize(string=>'shared obj1');
  my $obj2=new testSerialize(string=>'shared obj2');
  my $obj3=new testSerialize(string=>'shared obj3');
  my $obj4=new testSerialize(string=>'shared obj4');
  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test('object_list_shared',$obj);
 
  my $obj1=new testSerialize(string=>'shared obj1');
  my $obj2=new testSerialize(string=>'shared obj2');
  my $obj3=new testSerialize(string=>'shared obj3');
  my $obj4=new testSerialize(string=>'shared obj4');
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('object_hash_shared',$obj);

  my $obj1=new testSerialize(string=>'shared obj1');
  my $obj2=new testSerialize(string=>'shared obj2');
  my $obj3=new testSerialize(string=>'shared obj3');
  my $obj4=new testSerialize(string=>'shared obj4');
  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('object_multi',$obj);
  
  my $obj=new testSerialize;
  $obj->{self_circular}=$obj;
  fetch_n_test('self_circular',$obj);
  
  my $obj=new testSerialize;
  $obj->{self_circular_shared1}=$obj;
  $obj->{self_circular_shared2}=$obj;
  fetch_n_test('self_circular_shared',$obj);

  my $obj=new testSerialize;
  $obj->{self_circular_list}=[$obj,$obj,$obj,$obj];
  fetch_n_test('self_circular_list',$obj);

  my $obj=new testSerialize;
  $obj->{self_circular_hash}={a=>$obj,b=>$obj,c=>$obj,d=>$obj};
  fetch_n_test('self_circular_hash',$obj);

  my $obj=new testSerialize(integer=>1234,
			    float=>12.34,
			    string=>'a string',
			    list=>[qw(a b c d)],
			    hash=>{a=>1,b=>2,c=>3,d=>4});
  $obj->{self_circular}=$obj;
  $obj->{self_circular_list}=[$obj,$obj,$obj,$obj];
  $obj->{self_circular_hash}={a=>$obj,b=>$obj,c=>$obj,d=>$obj};
  fetch_n_test('self_circular_multi',$obj);

  my $obj1=new testSerialize(string=>'shared obj1');
  my $obj2=new testSerialize(string=>'shared obj2');
  my $obj3=new testSerialize(string=>'shared obj3');
  my $obj4=new testSerialize(string=>'shared obj4');
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
  fetch_n_test('very_multi',$obj);

  untie %oid;
}
1;
