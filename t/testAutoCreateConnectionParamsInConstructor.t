##
# Blackbox test the overall funtionality of AutoDB:
## Tests %AUTODB autocreation without DB connection params given,
## but with connection params given through AutoDB constructor
##
use lib 't/';
use lib 'lib/';
use Test::More qw/no_plan/;
use Data::Dumper;
use Class::AutoDB;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
my($DBC, $DBH);

BEGIN {
 require 'DBConnector.pm';
 $DBC = new DBConnector;
 $DBH = $DBC->getDBHandle;
}


{
require 'TestAutoDB_4.pm';
# now create an object with the required connection params
  Class::AutoDB->new(
		                  -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
		                 );
		                                             
my $result = $DBH->selectall_hashref("show tables", 1);
 
ok(exists $result->{_autodb});
ok(exists $result->{testautodb_4});
ok(exists $result->{testautodb_4_other});
}

# cleanup
#&DBConnector::DESTROY;
