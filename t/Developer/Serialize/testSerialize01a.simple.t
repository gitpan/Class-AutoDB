use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize01;

# The testSerialize series tests Class::AutoDB::Serialize
# This test stores a series of simple objects for later 
# fetch by its companion testSerialize1b.simple.t

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
    my($key,$obj,$transients)=@_;
    $oid{$key}=$obj->oid;
    $obj->store($transients);
    ok(1,$key);
  }

  # Simple black box testing of the interface
  my $obj=new testSerialize(integer=>1234);
  my $oid=$obj->oid;
  my $db_obj;
  # dbh
  Class::AutoDB::Serialize->dbh($dbh); # this had to work to get this far, but do it anyway...
  ok($dbh==Class::AutoDB::Serialize->dbh,'dbh');

  # store / fetch (various flavors)
  $obj->store;
  ok(1,'store');
  $db_obj=$obj->fetch($oid);
  is_deeply($obj,$db_obj,'fetch as object method');
  $db_obj=Class::AutoDB::Serialize->fetch($oid);
  is_deeply($obj,$db_obj,'fetch as class method');
  $db_obj=Class::AutoDB::Serialize::fetch($oid);
  is_deeply($obj,$db_obj,'fetch as function');

  ####################
  # The next test fetches a non-existant object which generates an error
  $db_obj=undef;
  eval {$db_obj=$obj->fetch(0)}; # hopefully no object has oid 0
  ok(!$db_obj && $@,'fetch of nonexistant object');
  ####################

  # get obj2oid,oid (various flavors)
  is($oid,$obj->obj2oid,'obj2oid as object method (get)');
  is($oid,Class::AutoDB::Serialize->obj2oid($obj),'obj2oid as class method (get)');
  is($oid,Class::AutoDB::Serialize::obj2oid($obj),'obj2oid as function (get)');

  is($oid,$obj->oid,'oid as object method (get)');
  is($oid,Class::AutoDB::Serialize->oid($obj),'oid as class method (get)');
  is($oid,Class::AutoDB::Serialize::oid($obj),'oid as function (get)');

  # get oid2obj (various flavors)
  is_deeply($obj,$obj->oid2obj($oid),'oid2obj as object method (get)');
  is_deeply($obj,Class::AutoDB::Serialize->oid2obj($oid),'oid2obj as class method (get)');
  is_deeply($obj,Class::AutoDB::Serialize::oid2obj($oid),'oid2obj as function (get)');

  # set obj2oid,oid (various flavors)
  $oid=1234;
  is($oid,$obj->obj2oid($oid),'obj2oid as object method (set)');
  is($oid,Class::AutoDB::Serialize->obj2oid($obj,$oid),'obj2oid as class method (set)');
  is($oid,Class::AutoDB::Serialize::obj2oid($obj,$oid),'obj2oid as function (set)');

  is($oid,$obj->oid($oid),'oid as object method (set)');
  is($oid,Class::AutoDB::Serialize->oid($obj,$oid),'oid as class method (set)');
  is($oid,Class::AutoDB::Serialize::oid($obj,$oid),'oid as function (set)');

  # set oid2obj (various flavors)
  is_deeply($obj,$obj->oid2obj($oid,$obj),'oid2obj as object method (get)');
  is_deeply($obj,Class::AutoDB::Serialize->oid2obj($oid,$obj),'oid2obj as class method (get)');
  is_deeply($obj,Class::AutoDB::Serialize::oid2obj($oid,$obj),'oid2obj as function (get)');

  # Test store of simple objects. Companion test does fetches
  my $obj=new testSerialize;	# empty object
  store('empty',$obj);

  my $obj=new testSerialize(integer=>1234);
  store('integer',$obj);

  my $obj=new testSerialize(float=>12.34);
  store('float',$obj);

  my $obj=new testSerialize(string=>'a string');
  store('string',$obj);

  my $obj=new testSerialize(list=>[qw(a b c d)]);
  store('list',$obj);;

  my $obj=new testSerialize(hash=>{a=>1,b=>2,c=>3,d=>4});
  store('hash',$obj);

  my $obj=new testSerialize(integer=>1234,
			     float=>12.34,
			     string=>'a string',
			     list=>[qw(a b c d)],
			     hash=>{a=>1,b=>2,c=>3,d=>4});
  store('simple_multi',$obj);
  
  # Test boundary cases for store of simple objects. Companion test does fetches
  my $obj=new testSerialize(integer=>0);
  store('integer_0',$obj);

  my $obj=new testSerialize(float=>0);
  store('float_0',$obj);

  my $obj=new testSerialize(string=>'');
  store('string_empty',$obj);

  my $obj=new testSerialize(list=>[]);
  store('list_0',$obj);;
  my $obj=new testSerialize(list=>[qw(a)]);
  store('list_1',$obj);;
  my $obj=new testSerialize(list=>[qw(a b)]);
  store('list_2',$obj);;
  my $obj=new testSerialize(list=>[qw(a b c)]);
  store('list_3',$obj);;

  my $obj=new testSerialize(hash=>{});
  store('hash_0',$obj);
  my $obj=new testSerialize(hash=>{a=>1});
  store('hash_1',$obj);
  my $obj=new testSerialize(hash=>{a=>1,b=>2});
  store('hash_2',$obj);
  my $obj=new testSerialize(hash=>{a=>1,b=>2,c=>3});
  store('hash_3',$obj);

  my $obj=new testSerialize(list=>[[]]);
  store('list_list_1',$obj);;
  my $obj=new testSerialize(list=>[[],[]]);
  store('list_list_2',$obj);;
  my $obj=new testSerialize(list=>[[],[],[]]);
  store('list_list_3',$obj);;

  my $obj=new testSerialize(hash=>{a=>{}});
  store('hash_hash_1',$obj);
  my $obj=new testSerialize(hash=>{a=>{},b=>{}});
  store('hash_hash_2',$obj);
  my $obj=new testSerialize(hash=>{a=>{},b=>{},c=>{}});
  store('hash_hash_3',$obj);

  # Test transient attribues.  Companion test does fetches
  my $obj=new testSerialize(integer=>1234,
			    tran1=>'this string should not be stored');
  store('transients_1',$obj,['tran1']);
  my $obj=new testSerialize(integer=>1234,
			    tran1=>'this string should not be stored',
			    tran2=>'this string should not be stored');
  store('transients_2',$obj,['tran1','tran2']);
  

  untie %oid;
}
1;

done_testing();
