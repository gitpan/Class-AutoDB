use strict;
use lib qw(. t ../lib);
use Class::AutoDB;
use Person;
use DBConnector;

my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        );


my $joe=new Person(-name=>'Joe',-sex=>'male',
		-alias=>'Joe Alias',
		-hobbies=>['mountain climbing', 'sailing']);
my $mary=new Person(-name=>'Mary',-sex=>'female',
		-alias=>'Mary Alias',
		-hobbies=>['hang gliding']);
my $bill=new Person(-name=>'Bill',-sex=>'male');

# Set up friends lists
$joe->friends([$mary,$bill]);
$mary->friends([$joe,$bill]);
$bill->friends([$joe,$mary]);
# No need to explicitly store the objects. AutoDB willstore them
# automatically when they are no longer referenced or when the program ends
