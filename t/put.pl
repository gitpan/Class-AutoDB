package Person;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS %AUTODB);
use lib qw(. t ../lib);
use Class::AutoClass;
use Data::Dumper; ## only for testing
use DBConnector;

@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name sex friends);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(
	 -collection=>'Person',
	 -keys=>qq(name string, sex string, friends list(string)));
Class::AutoClass::declare(__PACKAGE__);

package main;
use strict;
use Class::AutoDB;

#my $autodb=new Class::AutoDB(-dsn=>'DBI:mysql:database=AutoMagic__testSuite;host=localhost',-user=>'root');
my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 

my $joe=new Person(-name=>'Joe',-sex=>'male');
my $mary=new Person(-name=>'Mary',-sex=>'female');
my $bill=new Person(-name=>'Bill',-sex=>'male');

# Set up friends lists
print "*** assigning joe's friends\n";
$joe->friends([$mary,$bill]);
print "*** assigning mary's friends\n";
$mary->friends([$joe,$bill]);
print "*** assigning bill's friends\n";
$bill->friends([$joe,$mary,'a doll named sue']);
#$bill->friends(['something new and unexpected']); # lists should be growable

# No need to explicitly store the objects.  AutoDB will store them
# automatically when they are no longer referenced or when the program ends
