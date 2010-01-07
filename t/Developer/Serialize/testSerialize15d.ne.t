use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize15;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companions test overloading of the
# stringify operator and related operators 'eq' and 'ne'
# This test code in Oid.pm

my %oid;
SKIP: {
  # make sure databases exist
  my $dbh=DBI->connect('dbi:mysql:database=test');
  skip "! Cannot connect to database: ".$dbh->errstr."\n".
    "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
      if $dbh->err;
  my $tie=tie(%oid, 'SDBM_File', 'testSerialize.sdbm', O_RDWR, 0666);
  skip "! Cannot open SDBM file 'testSerialize.sdbm': ".$!."\n".
    "These tests require an SDBM file named 'testSerialize.sdbm'.  The user running the test must have permission to read and write this file."
      unless $tie;

  Class::AutoDB::Serialize->dbh($dbh);
}
my $OBJECTS=5;
my $root=Class::AutoDB::Serialize->fetch($oid{'root'});
my @objects=@{$root->list};
my @objects1=@{$root->list1};
my @objects2=@{$root->list2};

ok(@objects==$OBJECTS&&@objects1==$OBJECTS&&@objects2==$OBJECTS,
   "root points to $OBJECTS objects (all 3 lists)");
my @refs_oid=map {ref $_} @objects;
my @refs_oid1=map {ref $_} @objects1;
my @refs_oid2=map {ref $_} @objects2;
ok(grep(/Class::AutoDB::Oid/,@refs_oid1)==$OBJECTS,"before ne: objects in list are Oids");
ok(grep(/Class::AutoDB::Oid/,@refs_oid1)==$OBJECTS,"before ne: objects in list1 are Oids");
ok(grep(/Class::AutoDB::Oid/,@refs_oid2)==$OBJECTS,"before ne: objects in list2 are Oids");

my $errors;
for (my $i=0;$i<$OBJECTS;$i++) {
  $errors++ if $objects1[$i] ne $objects2[$i];
  $errors++ if $i!=0 && !($objects1[$i] ne $objects[0]);
}
ok(!$errors,"examined $OBJECTS objects: $errors ne errors");
my @refs_real=map {ref $_} @objects;
my @refs_real1=map {ref $_} @objects1;
my @refs_real2=map {ref $_} @objects2;
ok(grep(/testSerialize/,@refs_real)==$OBJECTS,"after ne: objects in list are real objects");
ok(grep(/testSerialize/,@refs_real1)==$OBJECTS,"after ne: objects in list1 are real objects");
ok(grep(/testSerialize/,@refs_real2)==$OBJECTS,"after ne: objects in list2 are real objects");

my $id_errors=0;
my $str_errors=0;
my $ref_errors=0;
for (my $i=0;$i<$OBJECTS;$i++) {
  my $obj=$objects1[$i];
  $id_errors++ unless $obj->id==$i;
  $str_errors++ if $obj ne $objects[$i];
  $ref_errors++ if ref $obj ne $refs_real[$i];
}
ok(!($id_errors+$str_errors+$ref_errors),
   "examined $OBJECTS objects in list1: $id_errors id errors, $str_errors stringify errors, $ref_errors ref errors");
  
untie %oid;

1;

done_testing();
