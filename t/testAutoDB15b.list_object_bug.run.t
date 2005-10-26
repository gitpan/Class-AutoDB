use lib qw(./t blib/lib);
use strict;
use Class::AutoDB;
use Person;
use Test::More qw/no_plan/;
use Data::Dumper;

# retrieve object that was written in setup test
my $autodb=new Class::AutoDB(-database=>'test');
# retrieve and check
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
my $joe=$cursor->get->[0];
is(ref $joe,'Person');
is(scalar @{$joe->friends}, 2);
my $bill=$joe->friends->[1];
ok(ref $bill,'Bill is an object before put');
is($bill->name, 'Bill');

# put Joe and retest
$joe->put;
my $bill=$joe->friends->[1];
ok(ref $bill,'Bill is an object after put');
is($bill->name, 'Bill');

# fetch again and retest
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joey');
my $joey=$cursor->get->[0];
is(scalar @{$joe->friends}, 2);
my $bill=$joe->friends->[1];
ok(ref $bill,'Bill is an object after refetch');
is($bill->name, 'Bill');

