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

my $joe=new Person(-name=>'Joe',-sex=>'male');
my $mary=new Person(-name=>'Mary',-sex=>'female');
my $bill=new Person(-name=>'Bill',-sex=>'male');

#
# Set up friends lists
print "*** assigning joe's friends\n";
$joe->friends([$mary,$bill]);
print "*** assigning mary's friends\n";
$mary->friends([$joe,$bill]);
print "*** assigning bill's friends\n";
$bill->friends([$joe,$mary,'a doll named sue']);

# No need to explicitly store the objects.  AutoDB will store them
# automatically when they are no longer referenced or when the program ends

#$joe->store;
#$bill->store;
#$mary->store;