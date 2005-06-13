use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use YAML;
use Scalar::Util qw(refaddr);
use Class::AutoDB::Serialize;
use testSerialize02;

# The testSerialize series tests Class::AutoDB::Serialize
# This test fetched a series of objects with independent objects
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

  my $refaddr_obj0;		# refaddr for obj0 in 'single shared object' tests
  my @refaddrs;			# 'local' refaddr's
  sub fetch_n_test_shared {
    my($key,$obj)=@_;
    my $db_obj=Class::AutoDB::Serialize->fetch($oid{$key});
    fetch_n_test($key,$obj);
    # There should be exactly one 'obj0' shared by all db objects
    %fetch_seen=();
    @refaddrs=();
    refaddrs($db_obj);
    $refaddr_obj0=$refaddrs[0] unless defined $refaddr_obj0;
    my @newaddrs=grep {$_!=$refaddr_obj0} @refaddrs;
    ok(!@newaddrs,"$key: shared structure");
  }
  sub refaddrs {
    my($value)=@_;
    return if $fetch_seen{$value};
    $fetch_seen{$value}=$value;
    if (UNIVERSAL::isa($value,'testSerialize') && $value->{string} eq 'obj0') {
      push(@refaddrs,refaddr($value));
    }
    return unless ref $value;
    if ('ARRAY' eq ref $value) {
      map {refaddrs($_)} @$value;
    } elsif (UNIVERSAL::isa($value,'HASH')) {
      map {refaddrs($_)} values %$value;
    }
  }
  
  my $obj1=new testSerialize(string=>'obj1');
  my $obj2=new testSerialize(string=>'obj2');
  my $obj3=new testSerialize(string=>'obj3');
  my $obj4=new testSerialize(string=>'obj4');

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
  my $obj1=new testSerialize(string=>'obj1'); $obj1->{self_circular}=$obj1;
  my $obj2=new testSerialize(string=>'obj2'); $obj2->{self_circular}=$obj2;
  my $obj3=new testSerialize(string=>'obj3'); $obj3->{self_circular}=$obj3;
  my $obj4=new testSerialize(string=>'obj4'); $obj4->{self_circular}=$obj4;

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

  # Do it again with a single shared object
  my $obj0=new testSerialize(string=>'obj0');
  fetch_n_test('one_shared_obj0',$obj0);
  my $db_obj0=Class::AutoDB::Serialize->fetch($oid{'one_shared_obj0'});
  # Change the shared object (in-memory and database) 
  # and show that it's really shared
  $obj0->{changed}=1;
  $db_obj0->{changed}=1;
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
  my $obj0=new testSerialize(string=>'obj0 self_circular');
  $obj0->{self_circular}=$obj0;
  fetch_n_test_shared('one_shared_self_circular_obj0',$obj0);
  my $db_obj0=Class::AutoDB::Serialize->fetch($oid{'one_shared_self_circular_obj0'});
  # Change the shared object (in-memory and database) 
  # and show that it's really shared
  $obj0->{changed}=1;
  $db_obj0->{changed}=1;
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
