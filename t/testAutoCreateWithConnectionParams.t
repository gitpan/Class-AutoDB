##
# Blackbox test the overall funtionality of AutoDB:
## tests %AUTODB auto creation with DB connection parameters given
##
use lib 't/';
use lib 'lib/';
use Test::More tests=>3;
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
require 'TestAutoDB_3.pm';
# test that correct tables are written
my $result = $DBH->selectall_hashref("show tables", 1);
ok(exists $result->{_autodb});
ok(exists $result->{testautodb_3});
ok(exists $result->{testautodb_3_other});
}

# cleanup
# &DBConnector::DESTROY;
