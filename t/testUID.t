use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB::SmartProxy;
use strict;

use constant MAX => 1000;
my $sp = new Class::AutoDB::SmartProxy;

for (1..MAX) {
 ok($sp->is_valid_key($sp->_getUID));
}
