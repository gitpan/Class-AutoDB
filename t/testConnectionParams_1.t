## test connection with dsn entry

use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use DBConnector;
use strict;
use TestAutoDB_1;
use TestAutoDB_2;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);

my  $DBC = new DBConnector(noclean=>1);
my  $DBH = $DBC->getDBHandle;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

my $autodb = Class::AutoDB->new(
	                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
	                          -user=>$DBConnector::DB_USER,
	                          -password=>$DBConnector::DB_PASS
	                        );

my %result = map {lc($_), 1} keys %{$DBH->selectall_hashref("show tables", 1)};

ok(exists $result{_autodb});
ok(exists $result{testautodb_1});
ok(exists $result{testautodb_1_other});
ok(exists $result{testautodb_2});
ok(exists $result{testautodb_2_other});
}


