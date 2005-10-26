use Class::AutoDB;
use Person;
use Test::More qw/no_plan/;
use Data::Dumper;

# retrieve object that was written in setup test
my $autodb=new Class::AutoDB(-database=>'test');
# retrieve and check
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
my $joe=$cursor->get->[0];
is(scalar @{$joe->friends}, 2);
is($joe->friends->[1]->name, 'Bill');

# mutate and store
$joe->name('Joey');
$joe->put;

# and later...
sleep 2;

my $cursor=$autodb->find(-collection=>'Person',-name=>'Joey');
my $joey=$cursor->get->[0];
is(scalar @{$joe->friends}, 2);
is($joey->friends->[1]->name, 'Bill');

