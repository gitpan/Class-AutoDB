##
# Blackbox test the overall funtionality of AutoDB
## Test that nested references are reachable
## such that for the structure:
#
#$VAR1 = bless( {
#                 '__proxyobj' => 1,
#                 '__object_id' => '511214490',
#                 'friends' => [
#                                bless( {
#                                         'UID' => '511139542',
#                                         'friends' => [
#                                                        bless( {
#                                                                 'UID' => '511214490',
#                                                                 'name' => 'Joe',
#                                                                 'sex' => 'male'
#                                                               }, 'Thing' ),
#                                                        bless( {
#                                                                 'UID' => '511275525',
#                                                                 'friends' => [
#                                                                                $VAR1->{'friends'}[0]
#                                                                              ],
#                                                                 'name' => 'Chris',
#                                                                 'sex' => 'male'
#                                                               }, 'Thing' )
#                                                      ],
#                                         'name' => 'Eddy',
#                                         'sex' => 'male'
#                                       }, 'Thing' )
#                              ],
#                 'name' => 'Joe',
#                 'sex' => 'male'
#               }, 'Thing' );
#               
# chris->friends->[0]->name is "Eddy"
# joe->friends->[0]->name is "Eddy"
# eddy->friends->[0]->name is "Joe"
# eddy->friends->[1]->name is "Chris"


use lib qw(. t ../lib);
use strict;
use Scalar::Util;
use Thing;
use DBConnector;
use Class::AutoClass;
use Test::More qw/no_plan/;

my($joe, $chris, $eddy, $thelma);

# populate the collection
{                          
$joe = new Thing(-name=>'Joe',-sex=>'male');
$chris = new Thing(-name=>'Chris',-sex=>'male');
$eddy = new Thing(-name=>'Eddy',-sex=>'male');
$thelma = new Thing(-name=>'Thelma',-sex=>'female');

## test cyclical refs
$eddy->friends([$joe,$chris]);
$joe->friends($eddy);
$chris->friends([$eddy]);
$thelma->friends([$eddy]); # and by association, joe and chris
}

# create AutoDB obj for storage
my $autodb =
  Class::AutoDB->new(
                            -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
			                -user=>$DBConnector::DB_USER,
			                -password=>$DBConnector::DB_PASS
		                  );

# destroy the Thing objects (force them to store)
&Class::AutoClass::DESTROY($joe);
&Class::AutoClass::DESTROY($chris);
&Class::AutoClass::DESTROY($eddy);
&Class::AutoClass::DESTROY($thelma);

{
my $cursor = $autodb->find(-collection=>'Thing');
my @stuff = $cursor->get;
#print Dumper @stuff;
my $joe = $stuff[0];
my $chris = $stuff[1];
my $eddy = $stuff[2];
my $thelma = $stuff[3];

is($thelma->name,"Thelma","scalar written to database");
is(ref($thelma->friends),'ARRAY',"list written to database");
is($chris->name,"Chris","scalar written to database");
is(ref($chris->friends),'ARRAY',"list written to database");
is($eddy->name,"Eddy","scalar written to database");
is(ref($eddy->friends),'ARRAY',"list written to database");
is($joe->name,"Joe","scalar written to database");
is(ref($joe->friends),'ARRAY',"list written to database");

# get to friends through other friends... just like Friendster :)
is($chris->friends->[0]->name, "Eddy");
is($joe->friends->[0]->name, "Eddy");
is($eddy->friends->[0]->name, "Joe");
is($eddy->friends->[1]->name, "Chris");
is($thelma->friends->[0]->name, "Eddy");

$eddy = $chris->friends; # eddy is friend of chris
#print Dumper $eddy->[0];
is(ref($eddy->[0]), "Thing");
is(ref($eddy->[0]->friends->[0]), "Thing");
is(ref($eddy->[0]->friends->[1]), "Thing");
$eddy = $joe->friends; # eddy is friend of joe
is(ref($eddy->[0]), "Thing");
is(ref($eddy->[0]->friends->[0]), "Thing");
is(ref($eddy->[0]->friends->[1]), "Thing");
is($thelma->friends->[0]->name, "Eddy");# eddy is a friend of Thelma


# is this supposed to work? will have to look up by UID and create new instance
#skip {
#  is($eddy_friends->friends->[0]->name, "Joe");
#  is($eddy_friends->friends->[0]->name, "Chris");
# };

}
