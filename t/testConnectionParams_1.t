## test connection with dsn entry

use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
#use Data::Dumper; # only for testing
use DBConnector;
use strict;
use TestAutoDB_1;
use TestAutoDB_2;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);

my  $DBC = new DBConnector;
my  $DBH = $DBC->getDBHandle;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

my $autodb = Class::AutoDB->new(
	                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
	                          -user=>$DBConnector::DB_USER,
	                          -password=>$DBConnector::DB_PASS
	                        );

my $result = $DBH->selectall_hashref("show tables", 1);
ok(not exists $result->{_AutoDB});
ok(not exists $result->{TestAutoDB_1});
ok(not exists $result->{TestAutoDB_1_other});
ok(not exists $result->{TestAutoDB_2});
ok(not exists $result->{TestAutoDB_2_other});
}


