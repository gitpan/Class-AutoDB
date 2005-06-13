use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize06;

# The testSerialize series tests Class::AutoDB::Serialize
# This test tests repeated fetch, update, and store of simple objects

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
  my %oid2counter;
  my $tie=tie(%oid2counter, 'SDBM_File', 'testSerialize_counter.sdbm', O_RDWR, 0666);
  skip "! Cannot open SDBM file 'testSerialize_counter.sdbm': ".$!."\n".
    "These tests require an SDBM file named 'testSerialize_counter.sdbm'.  The user running the test must have permission to read and write this file."
      unless $tie;

  Class::AutoDB::Serialize->dbh($dbh);

  sub fetch_n_inc {
    my($key,$obj0)=@_;
    my $oid=$oid{$key};
    if (!$oid) {		# first time, so first store object
      $oid=$obj0->oid;
      $oid{$key}=$oid;
      $obj0->store;
      $oid2counter{$oid}=1;
      ok(1,"$key initialize");
    }
    my $db_obj0=Class::AutoDB::Serialize->fetch($oid);
    my $counter=$oid2counter{$oid};
    is($counter,$db_obj0->{counter},"counter=$counter");
    $db_obj0->{counter}++;
    $obj0->{counter}=$db_obj0->{counter};
    $oid2counter{$oid}++;
    $db_obj0->store;
  }
  sub fetch_n_test {
    my($key,$obj0,$obj)=@_;
    my $oid=$oid{$key};
    if (!$oid) {		# first time, so first store object
      $oid=$obj->oid;
      $oid{$key}=$oid;
      $obj->store;
      ok(1,"$key initialize");
    }
    my $db_obj=Class::AutoDB::Serialize->fetch($oid);
    is_deeply($obj,$db_obj,"$key: before increments");
    for (1..10) {
      fetch_n_inc('multistore_simple',$obj0);
    }
    my $db_obj=Class::AutoDB::Serialize->fetch($oid);
    is_deeply($obj,$db_obj,"$key: after increments");
  }

  my $obj0=new testSerialize(counter=>1);
  for (1..10) {
    fetch_n_inc('multistore_simple',$obj0);
  }
  my $obj=new testSerialize(object=>$obj0);
  fetch_n_test('multistore_object',$obj0,$obj);

  my $obj=new testSerialize(object_list=>[$obj0,$obj0,$obj0,$obj0]);
  fetch_n_test('multistore_object_list',$obj0,$obj);
  
  my $obj=new testSerialize(object_hash=>{a=>$obj0,b=>$obj0,c=>$obj0,d=>$obj0});
  fetch_n_test('multistore_object_hash',$obj0,$obj);
  
  untie %oid;
  untie %oid2counter;
}
1;
