use lib qw(. t ../lib);
use strict;
use Person;
use DBConnector;
use Test::More qw/no_plan/;
use Class::AutoDB;

my $DBC = new DBConnector;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

	my $autodb = Class::AutoDB->new(
	                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
	                          -user=>$DBConnector::DB_USER,
	                          -password=>$DBConnector::DB_PASS
	                        ); 
	
	my $joe=new Person(-name=>'Joe',-sex=>'male');
	my $mary=new Person(-name=>'Mary',-sex=>'female');
	my $bill=new Person(-name=>'Bill',-sex=>'male');
	my $eddy=new Person(-name=>'Eddy',-sex=>'male',-friends=>[qq/I'm working on it/]);
	
	# Set up friends lists (Eddy's was set up in constructor)
	$joe->friends([$mary,$bill]);
	$mary->friends([$joe,$bill]);
	$bill->friends([$joe,$mary,'a doll named sue']);
	
	# TODO:  lists should be growable??
	# $bill->friends(['someone new and unexpected']);
	# bill should now have 4 friends
	
	# Query the database
	my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
	
	#print "Number of Joe's in database: ",$cursor->count,"\n";
	#while (my $joe=$cursor->get_next) {          # Loop getting the objects one by one
	
	my @joes=$cursor->get;
    my $friends=$joe->friends;
    is($friends->[0]->name, 'Mary');
    is($friends->[1]->name, 'Bill');
    
    # alter the search keys
    $joe->name("Joey");
    $joe->friends([$eddy]);
    
    # test that the list search keys were updated
    my $joe_id=$joe->{__object_id};
    my $eddy_id=$eddy->{__object_id};
    my $dbh=$DBC->getDBHandle;
	my $sql = qq/select * from Person_friends where object='$joe_id'/;
 	my $result = $dbh->selectall_arrayref($sql);
 	my $thaw;
 	eval $result->[0][1]; # sets $thaw
 	is($thaw->[0],$eddy_id);

    
    # test that values are updated
    is($joe->name,'Joey','simple key altered correctly');
    is($joe->friends->[0]->name,'Eddy','list search keys altered correctly');
    # Mary's first friend is Joe (who now goes by "Joey" and who has changed his best friend)
    my $joe_through_mary = $mary->friends->[0];
    is($joe_through_mary->name, 'Joey');
    is($joe_through_mary->friends->[0]->name,'Eddy');
    # finally, check that Eddy's friend list was created way back at construction
    is($eddy->friends->[0],qq/I'm working on it/);
    
  my ($lucy,$ethel);
 $ethel = Person->new(-name=>'Ethel', -sex=>'female', -friends=>[ $lucy ] );
 $lucy = Person->new(-name=>'Lucy', -sex=>'female', -friends=>[ $ethel ] );
 
 is($lucy->friends->[0]->name, 'Ethel');
 is($ethel->friends->[0],undef,'object list was undefined at time of assignment');
    
}