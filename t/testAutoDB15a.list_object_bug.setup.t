use lib qw(./t blib/lib);
use strict;
use Class::AutoDB;
use Person;
use Test::More qw/no_plan/;
use Data::Dumper;

my $autodb=new Class::AutoDB(-database=>'test', create=>1);
my $joe=new Person(-name=>'Joe',-sex=>'male');
my $mary=new Person(-name=>'Mary',-sex=>'female');
my $bill=new Person(-name=>'Bill',-sex=>'male');
# Set up friends lists
$joe->friends([$mary,$bill]);
$mary->friends([$joe,$bill]);
$bill->friends([$joe,$mary]);
$autodb->put_objects;           # store objects in database
ok(1,'end of test');
