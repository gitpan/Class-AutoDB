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

# Test with cursor
my $cursor=$autodb->find(-collection=>'Person');
is($cursor->count,3,"cursor count: Person");
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
is($cursor->count,1,"cursor count: Joe");
my $cursor=$autodb->find(-collection=>'Person',-name=>'Mary');
is($cursor->count,1,"cursor count: Mary");
my $cursor=$autodb->find(-collection=>'Person',-name=>'Bill');
is($cursor->count,1,"cursor count: Bill");

# Do it again without cursor
my $count=$autodb->count(-collection=>'Person');
is($count,3,"autodb count: Person");
my $count=$autodb->count(-collection=>'Person',-name=>'Joe');
is($count,1,"autodb count: Joe");
my $count=$autodb->count(-collection=>'Person',-name=>'Mary');
is($count,1,"autodb count: Mary");
my $count=$autodb->count(-collection=>'Person',-name=>'Bill');
is($count,1,"autodb count: Bill");

# Test mixing count and get
my $cursor=$autodb->find(-collection=>'Person');
is($cursor->count,3,"cursor count: Person");
my @persons=$cursor->get;
cmp_bag(\@persons,[$joe,$bill,$mary],"get after count");
is($cursor->count,3,"count after get");

my @persons;
$cursor->reset;
while (my $person=$cursor->get_next) {
  push(@persons,$person);
}
cmp_bag(\@persons,[$joe,$bill,$mary],"get_next after count");

my @persons;
$cursor->reset;
while (my $person=$cursor->get_next) {
  push(@persons,$person);
  is($cursor->count,3,"count inside get_next loop");
}
cmp_bag(\@persons,[$joe,$bill,$mary],"get_next with count inside loop");

