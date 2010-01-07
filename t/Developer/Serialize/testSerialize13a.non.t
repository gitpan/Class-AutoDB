use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Class::AutoDB::Serialize;
use testSerialize13;

# The testSerialize series tests Class::AutoDB::Serialize
# This test and its companion implement a non-Serialize-able
# example

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

  sub chain {
    my($prev,$next)=@_;
    $prev->next($next);
    $next->prev($prev);
  }

  my $bar=new Bar(-message=>'bar 0');
  my $hello=new Foo(-message=>'hello world',-bar=>$bar);
  my $visit=new Foo(-message=>'visit world',-bar=>$bar);
  my $goodbye=new Foo(-message=>'goodbye world',-bar=>$bar);
  my $after_bar=new Foo(-message=>'after bar',-bar=>$bar);

  chain($hello,$visit);
  chain($visit,$goodbye);
  chain($bar,$after_bar);
  $hello->list([$hello,$visit,$goodbye]);
  $visit->list([$visit,$goodbye,$hello]);
  $goodbye->list([$goodbye,$hello,$visit]);
  
  $hello->store;
  $visit->store;
  $goodbye->store;
  $after_bar->store;

  $oid{'hello'}=$hello->oid;
  $oid{'after_bar'}=$after_bar->oid;
  ok(1,"created and stored foobar objects");

  untie %oid;
}

done_testing();
