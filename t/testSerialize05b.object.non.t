use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use YAML;
use Scalar::Util qw(refaddr);
use Class::AutoDB::Serialize;
use testSerialize05;

# The testSerialize series tests Class::AutoDB::Serialize
# This test fetches a series of objects  with independent objects that are
# not decendants of Class::AutoDB:Serialize
# stored by its companion test

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
    %fetch_seen=undef;
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
  my %refaddr_non;		# refaddr's seen for non-Serialize-able objects in 'non' test
  my @refaddrs;			# 'local' refaddr's
  sub fetch_n_test_shared {
    my($key,$obj)=@_;
    my $db_obj=Class::AutoDB::Serialize->fetch($oid{$key});
    fetch_n_test($key,$obj);
    # expect repeated refaddr's for non-Serialize-able objects seen
    # within one object, but no repeats from different objects
    %fetch_seen=();
    @refaddrs=();
    refaddrs($db_obj);
    my @repeats=grep {defined $_} @refaddr_non{@refaddrs};
    ok(!@repeats,"$key: shared structure");
    @refaddr_non{@refaddrs}=@refaddrs;
  }
  sub refaddrs {
    my($value)=@_;
    return if $fetch_seen{$value};
    $fetch_seen{$value}=$value;
    if (UNIVERSAL::isa($value,'testNonSerialize')) {
      push(@refaddrs,refaddr($value));
    }
    return unless ref $value;
    if ('ARRAY' eq ref $value) {
      map {refaddrs($_)} @$value;
    } elsif (UNIVERSAL::isa($value,'HASH')) {
      map {refaddrs($_)} values %$value;
    }
  }
  
  # create the independent objects -- don't store since they're not Serialize-able
  my $obj1=new testNonSerialize(string=>'obj1');
  my $obj2=new testNonSerialize(string=>'obj2');
  my $obj3=new testNonSerialize(string=>'obj3');
  my $obj4=new testNonSerialize(string=>'obj4');

  # Now do the tests
  my $obj=new testSerialize(object=>$obj1);
  fetch_n_test('object',$obj);
  
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test('object_list',$obj);
  
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('object_hash',$obj);
  
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  fetch_n_test('object_shared',$obj);
  
  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test('object_list_shared',$obj);
 
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('object_hash_shared',$obj);

  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('object_multi',$obj);

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
  fetch_n_test('self_circular_multi',$obj);

  # Do it again with self-circular objects
  my $obj1=new testNonSerialize(string=>'obj1'); $obj1->{self_circular}=$obj1;
  my $obj2=new testNonSerialize(string=>'obj2'); $obj2->{self_circular}=$obj2;
  my $obj3=new testNonSerialize(string=>'obj3'); $obj3->{self_circular}=$obj3;
  my $obj4=new testNonSerialize(string=>'obj4'); $obj4->{self_circular}=$obj4;

  my $obj=new testSerialize(object=>$obj1);
  fetch_n_test('self_circular_object',$obj);
  
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test('self_circular_object_list',$obj);
  
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('self_circular_object_hash',$obj);
  
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  fetch_n_test('self_circular_object_shared',$obj);

  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test('self_circular_object_list_shared',$obj);
 
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('self_circular_object_hash_shared',$obj);

  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test('self_circular_object_multi',$obj);

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
  fetch_n_test('self_circular_self_circular_multi',$obj);

  # Do it again with a single shared object. 
  # Although the object was shared when stored, it should not be shared 
  # when fetched, since it's not a Serializeable-object
  my $obj0=new testNonSerialize(string=>'obj0');
  my $obj1=$obj0;
  my $obj2=$obj0;
  my $obj3=$obj0;
  my $obj4=$obj0;

  my $obj=new testSerialize(object=>$obj1);
  fetch_n_test_shared('one_shared_object',$obj);
  
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test_shared('one_shared_object_list',$obj);
  
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test_shared('one_shared_object_hash',$obj);
  
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  fetch_n_test_shared('one_shared_object_shared',$obj);

  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test_shared('one_shared_object_list_shared',$obj);
 
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test_shared('one_shared_object_hash_shared',$obj);

  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test_shared('one_shared_object_multi',$obj);

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
  fetch_n_test_shared('one_shared_self_circular_multi',$obj);

  # Do it again with single shared self-circular object
  my $obj0=new testNonSerialize(string=>'obj0 self_circular');
  $obj0->{self_circular}=$obj0;
  my $obj1=$obj0;
  my $obj2=$obj0;
  my $obj3=$obj0;
  my $obj4=$obj0;

  my $obj=new testSerialize(object=>$obj1);
  fetch_n_test_shared('one_shared_self_circular_object',$obj);
  
  my $obj=new testSerialize(object_list=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test_shared('one_shared_self_circular_object_list',$obj);
  
  my $obj=new testSerialize(object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test_shared('one_shared_self_circular_object_hash',$obj);
  
  my $obj=new testSerialize(object1=>$obj1,
			    object2=>$obj1);
  fetch_n_test_shared('one_shared_self_circular_object_shared',$obj);

  my $obj=new testSerialize(object_list1=>[$obj1,$obj2,$obj3,$obj4],
			     object_list2=>[$obj1,$obj2,$obj3,$obj4]);
  fetch_n_test_shared('one_shared_self_circular_object_list_shared',$obj);
 
  my $obj=new testSerialize(object_hash1=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4},
			     object_hash2=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test_shared('one_shared_self_circular_object_hash_shared',$obj);

  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4},
			     object_list=>[$obj1,$obj2,$obj3,$obj4],
			     object_hash=>{a=>$obj1,b=>$obj2,c=>$obj3,d=>$obj4});
  fetch_n_test_shared('one_shared_self_circular_object_multi',$obj);

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
  fetch_n_test_shared('one_shared_self_circular_self_circular_multi',$obj);

  untie %oid;
}
1;
