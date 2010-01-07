use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use autodbYAML;			# wrapper that shuts up 'deep recursion' warnings
use Class::AutoDB::Serialize;
use testSerialize01;

# The testSerialize series tests Class::AutoDB::Serialize
# This test fetches a series of objects stored by its 
# companion testSerialize1a.simpleet

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

  my $obj=new testSerialize;	# empty object
  fetch_n_test('empty',$obj);

  my $obj=new testSerialize(integer=>1234);
  fetch_n_test('integer',$obj);

  my $obj=new testSerialize(float=>12.34);
  fetch_n_test('float',$obj);

  my $obj=new testSerialize(string=>'a string');
  fetch_n_test('string',$obj);

  my $obj=new testSerialize(list=>[qw(a b c d)]);
  fetch_n_test('list',$obj);

  my $obj=new testSerialize(hash=>{a=>1,b=>2,c=>3,d=>4});
  fetch_n_test('hash',$obj);

  my $obj=new testSerialize(integer=>1234,
			    float=>12.34,
			    string=>'a string',
			    list=>[qw(a b c d)],
			    hash=>{a=>1,b=>2,c=>3,d=>4});
  fetch_n_test('simple_multi',$obj);
  
  # Test boundary cases for store of simple objects. Companion test does puts
  my $obj=new testSerialize(integer=>0);
  fetch_n_test('integer_0',$obj);

  my $obj=new testSerialize(float=>0);
  fetch_n_test('float_0',$obj);

  my $obj=new testSerialize(string=>'');
  fetch_n_test('string_empty',$obj);

  my $obj=new testSerialize(list=>[]);
  fetch_n_test('list_0',$obj);;
  my $obj=new testSerialize(list=>[qw(a)]);
  fetch_n_test('list_1',$obj);;
  my $obj=new testSerialize(list=>[qw(a b)]);
  fetch_n_test('list_2',$obj);;
  my $obj=new testSerialize(list=>[qw(a b c)]);
  fetch_n_test('list_3',$obj);;

  my $obj=new testSerialize(hash=>{});
  fetch_n_test('hash_0',$obj);
  my $obj=new testSerialize(hash=>{a=>1});
  fetch_n_test('hash_1',$obj);
  my $obj=new testSerialize(hash=>{a=>1,b=>2});
  fetch_n_test('hash_2',$obj);
  my $obj=new testSerialize(hash=>{a=>1,b=>2,c=>3});
  fetch_n_test('hash_3',$obj);

  my $obj=new testSerialize(list=>[[]]);
  fetch_n_test('list_list_1',$obj);;
  my $obj=new testSerialize(list=>[[],[]]);
  fetch_n_test('list_list_2',$obj);;
  my $obj=new testSerialize(list=>[[],[],[]]);
  fetch_n_test('list_list_3',$obj);;

  my $obj=new testSerialize(hash=>{a=>{}});
  fetch_n_test('hash_hash_1',$obj);
  my $obj=new testSerialize(hash=>{a=>{},b=>{}});
  fetch_n_test('hash_hash_2',$obj);
  my $obj=new testSerialize(hash=>{a=>{},b=>{},c=>{}});
  fetch_n_test('hash_hash_3',$obj);

  my $obj=new testSerialize(integer=>1234);
  fetch_n_test('transients_1',$obj);
  my $obj=new testSerialize(integer=>1234);
  fetch_n_test('transients_2',$obj);

  untie %oid;
}
1;

done_testing();
