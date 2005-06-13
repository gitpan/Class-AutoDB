use strict;
use lib qw(. t ../lib);
use Class::AutoDB;
use Person;
use DBConnector;
use YAML;

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
print "---- JOE ------\n";
print Dump($joe);
$mary->friends([$joe,$bill]);
print "---- MARY ------\n";
print Dump($mary);
$bill->friends([$joe,$mary]);
print "---- BILL ------\n";
print Dump($bill);
print Dump([$joe,$mary,$bill]);



# No need to explicitly store the objects. AutoDB will store them
# automatically when they are no longer referenced or when the program ends
