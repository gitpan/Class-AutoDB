##
# Blackbox test the overall funtionality of AutoDB:
## Tests %AUTODB autocreation without DB connection params given,
## but with connection params given through AutoDB constructor
##
use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use Data::Dumper; # only for testing
use DBConnector;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);

my  $DBC = new DBConnector;
my  $DBH = $DBC->getDBHandle;


# create autodb objects without a class behind it (Class::AutoDB::auto_register not called)
{
# in-memory registry should exist, but no database connection means no registry is written to DB                                                                 
my $autodb1 = new Class::AutoDB;                                                                                                                               
is(ref($autodb1->registry), "Class::AutoDB::Registry");                                                                                                          
is($autodb1->registry->_exists, 0, "_exists flag not set without auto register");                                              
is($autodb1->session, 0, "session flag=false without connected database");
my $result = $DBH->selectall_hashref("show tables", 1);
ok(not exists $result->{_autodb});
ok(not exists $result->{testautodb_4});
ok(not exists $result->{testautodb_4_other});


# now create an object with the required connection params, registry should be written to DB
my $autodb2 =  Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                    );

is($autodb2->registry->_exists, 0, "_exists flag=false without auto register");
is($autodb2->session, 1, "session flag=true with connected database");
my $result = $DBH->selectall_hashref("show tables", 1);
ok(not exists $result->{_autodb});
ok(not exists $result->{testautodb_4});
ok(not exists $result->{testautodb_4_other});
}


{
require 'TestAutoDB_4.pm';

# in-memory registry should exist, but no database connection means no registry is written to DB
my $autodb1 = new Class::AutoDB;
is(ref($autodb1->registry), "Class::AutoDB::Registry");
is($autodb1->registry->_exists, 0, "_exists flag not set in registry without connection parameters");
is($autodb1->session, 0, "session flag=false without connected database");
my $result = $DBH->selectall_hashref("show tables", 1);
ok(not exists $result->{_autodb});
ok(not exists $result->{testautodb_4});
ok(not exists $result->{testautodb_4_other});


# now create an object with the required connection params, registry should be written to DB
my $autodb2 =  Class::AutoDB->new(
		          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                  -user=>$DBConnector::DB_USER,
                  -password=>$DBConnector::DB_PASS
		    );
		    
is($autodb2->registry->_exists, 1, "_exists flag=true in registry with connection parameters");
is($autodb2->session, 1, "session flag=true with connected database");
my $result = $DBH->selectall_hashref("show tables", 1);
ok(exists $result->{_autodb});
ok(exists $result->{testautodb_4});
ok(exists $result->{testautodb_4_other});
}


## test that DN connection is defered until AutoDB's constructor is called
## this is how most people will probably connect

package Person;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS %AUTODB);
use Class::AutoClass;

@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name sex friends);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(
	 -collection=>'Person',
	 -keys=>qq(name string, sex string, friends list(string)));
Class::AutoClass::declare(__PACKAGE__);

package main;
use Class::AutoDB;

my $autodb3=new Class::AutoDB
  (-database=>$DBConnector::DB_DATABASE,-host=>$DBConnector::DB_SERVER,-user=>$DBConnector::DB_USER,-password=>$DBConnector::DB_PASS);

is($autodb3->registry->_exists, 1, "_exists flag set when connection params passed in AutoDB constructor");
is($autodb3->session, 1, "session flag=true with connected database");
my $result = $DBH->selectall_hashref("show tables", 1);
ok(exists $result->{_autodb});
ok(exists $result->{person});
ok(exists $result->{person_friends});

1;


