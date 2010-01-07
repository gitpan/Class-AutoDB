use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use autodbYAML;			# wrapper that shuts up 'deep recursion' warnings
use Class::AutoDB::Serialize;
use testSerialize12;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companion implement the 'person' example
# from the docs

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

  sub eq_list {
    my($a,$b)=@_;
    return undef unless 'ARRAY' eq ref $a && 'ARRAY' eq ref $b;  
    return undef unless @$a==@$b;
    for(my $i=0;$i<@$a;$i++) {
      return undef unless $a->[$i] == $b->[$i];
    }
    return 1;
  }

  my $joe=Class::AutoDB::Serialize->fetch($oid{'joe'});
  my $mary=Class::AutoDB::Serialize->fetch($oid{'mary'});
  my $bill=Class::AutoDB::Serialize->fetch($oid{'bill'});

  is('Joe',$joe->name,'Joe name');
  is('Mary',$mary->name,'Mary name');
  is('Bill',$bill->name,'Bill name');

  is('male',$joe->sex,'Joe sex');
  is('female',$mary->sex,'Mary sex');
  is('male',$bill->sex,'Bill sex');

  is_deeply(['mountain climbing','sailing'],$joe->hobbies,'Joe hobbies');
  is_deeply(['hang gliding'],$mary->hobbies,'Mary hobbies');
  is_deeply(['cooking','eating','sleeping'],$bill->hobbies,'Bill hobbies');

  ok(eq_list([$mary,$bill],$joe->friends),'Joe friends');
  ok(eq_list([$joe,$bill],$mary->friends),'Mary friends');
  ok(eq_list([$joe,$mary],$bill->friends),'Bill friends');

  untie %oid;
}
1;

done_testing();
