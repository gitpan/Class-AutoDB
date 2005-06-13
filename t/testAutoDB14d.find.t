use strict;
use Class::AutoDB;
use Test::More qw/no_plan/;
use Test::Deep;
use Set::Scalar;
use Class::AutoDB::Object;
use testAutoDB14;

# make sure we can talk to MySQL and database exists
our $dbh=DBI->connect('dbi:mysql:database=test');
die "! Cannot connect to database: ".$dbh->errstr."\n".
  "These tests require a MySQL database named 'test'.  The user running the test must have permission to create and drop tables, and select and update data."
  if $dbh->err;

my $autodb=new Class::AutoDB(-database=>'test');
sub is_shallow {
  my($results,$targets,$tag)=@_;
  my(%results,%targets);
  @results{@$results}=@$results;
  @targets{@$targets}=@$targets;
  my $ok=
    (scalar(keys %results)==scalar(keys %targets) &&
     scalar(grep {$targets{$_}} keys %results)==keys %results);
  ok($ok,$tag);
}

# create test objects -- last state of objects from testAutoDB14a.put.t
my $joe=new Person(-name=>'Joe',-sex=>'male');
my $mary=new Person(-name=>'Mary',-sex=>'female');
my $bill=new Person(-name=>'Bill',-sex=>'male');
# Set up friends lists
$joe->friends([$mary,$bill]);
$mary->friends([$joe,$bill]);
$bill->friends([$joe,$mary]);

my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe'); # run query
my @joes=$cursor->get;
is(scalar @joes,1,"get: number of joes");
$cursor->reset;
my $count=0;
while (my $joe=$cursor->get_next) {                # loop getting objects
  # $joe is a Person object -- do what you want with it
  my $friends=$joe->friends;
  my @names=map {$_->name} @$friends;
  cmp_bag(\@names,['Mary','Bill'],"joe's friends");
  $count++;
}
is($count,1,"get_next: number of joes");

my $cursor=$autodb->find(-collection=>'Person',-name=>'Mary'); # run query
my @marys=$cursor->get;
is(scalar @marys,1,"get: number of marys");
my $cursor=$autodb->find(-collection=>'Person',-name=>'Bill'); # run query
my @bills=$cursor->get;
is(scalar @bills,1,"get: number of bills");

my $joe=$joes[0];
my $mary=$marys[0];
my $bill=$bills[0];

is_shallow($joe->friends,[$mary,$bill],"joe's friends: exact same objects");
is_shallow($mary->friends,[$joe,$bill],"mary's friends: exact same objects");
is_shallow($bill->friends,[$mary,$joe],"bill's friends: exact same objects");


