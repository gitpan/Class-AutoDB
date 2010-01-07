use t::lib;
use strict;
use Test::More;
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use autodbYAML;			# wrapper that shuts up 'deep recursion' warnings
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

  sub eq_list {
    my($a,$b)=@_;
    return undef unless 'ARRAY' eq ref $a && 'ARRAY' eq ref $b;  
    return undef unless @$a==@$b;
    for(my $i=0;$i<@$a;$i++) {
      return undef unless $a->[$i] == $b->[$i];
    }
    return 1;
  }
  sub chain {
    my($prev,$next)=@_;
    $prev->next($next);
    $next->prev($prev);
  }

  my $hello=Class::AutoDB::Serialize->fetch($oid{hello});
  my $visit=$hello->next;
  my $goodbye=$visit->next;

  is('hello world',$hello->message,'hello message');
  is('visit world',$visit->message,'visit message');
  is('goodbye world',$goodbye->message,'goodbye message');

  ok(eq_list([$hello,$visit,$goodbye],$hello->list),'hello list');
  ok(eq_list([$visit,$goodbye,$hello],$visit->list),'visit list');
  ok(eq_list([$goodbye,$hello,$visit],$goodbye->list),'goodbye list');

  is('bar 0',$hello->bar->message,'hello bar before change');
  is('bar 0',$visit->bar->message,'visit bar before change');
  is('bar 0',$goodbye->bar->message,'goodbye bar before change');

  my $i=1;
  $hello->bar->message('bar '.$i++);
  $visit->bar->message('bar '.$i++);
  $goodbye->bar->message('bar '.$i++);
  is('bar 1',$hello->bar->message,'hello bar after change');
  is('bar 2',$visit->bar->message,'visit bar after change');
  is('bar 3',$goodbye->bar->message,'goodbye bar after change');

  my $after_bar=Class::AutoDB::Serialize->fetch($oid{after_bar});
  ok($after_bar==$hello->bar->next,'hello after_bar');
  ok($after_bar==$visit->bar->next,'visit after_bar');
  ok($after_bar==$goodbye->bar->next,'goodbye after_bar');

  untie %oid;
}
1;

done_testing();
