use strict;

use Class::AutoDB::Connect;
my $autodb=new Class::AutoDB::Connect(-database=>'test');
my $dbh=$autodb->dbh;


$dbh->do(q(delete from foo)) || die $dbh->errstr;

my $iters=$ARGV[0] || 10;
my @values=map {"($_)"} (1..$iters);
my $values='values'.join(', ',@values);
my $sql=qq(insert into foo(x) $values);
$dbh->do($sql) || die $dbh->errstr;

my $sql=qq(select x from foo);
my $sth=$dbh->prepare($sql) || die("Database error in prepare for query\n$sql\n".$dbh->errstr);
$sth->execute || die("Database error in exectue for query\n$sql\n".$dbh->errstr);

while(my $x=get_next()) {
  print "$x\n";
}
print "call get_next again\n";
while(my $x=get_next()) {
  print "$x\n";
}

sub get_next {
  return undef unless $sth->{Active};
  my($x)=$sth->fetchrow_array;
  if (!$x) {		# either end of results or error
    die("Database error in fetch for query\n$sql\n".$dbh->errstr) if $sth->err;
  }
  $x;
}

sub get {
  my($n)=@_;
  return undef unless $sth->{Active};
  my $results=$sth->fetchall_arrayref(undef,$n) || die("Database error in prepare for query\n$sql\n".$dbh->errstr);
  @$results=map {$_->[0]} @$results;
  wantarray? @$results: $results;
}
