use lib qw(.. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use DBConnector;
use Error qw(:try);
use strict;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);

my  $DBC = new DBConnector();
my  $DBH = $DBC->getDBHandle;
my $OBJECT_TABLE='_AutoDB';        # default for Object table

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;

	require 'TestAutoDB_1.pm';
	my $autodb = Class::AutoDB->new(
		                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
		                          -user=>$DBConnector::DB_USER,
		                          -password=>$DBConnector::DB_PASS
		                        );
	my $result = $DBH->selectall_hashref("select * from $OBJECT_TABLE",1);
	my $thaw;
	eval $result->{Registry}->{object}; #sets thaw
	is(scalar keys %{$thaw->{name2coll}}, 1);
	ok(defined $thaw->{name2coll}->{TestAutoDB_1});
	
	# passing create=1 flag should drop existing registry and collections and create new
	require 'TestAutoDB_2.pm';
	my $autodb2 = Class::AutoDB->new(
		                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
		                          -user=>$DBConnector::DB_USER,
		                          -password=>$DBConnector::DB_PASS,
		                          -create=>1
		                        );
	delete 	$autodb2->{registry}->{name2coll}->{TestAutoDB_1};
	my $result2 = $DBH->selectall_hashref("select * from $OBJECT_TABLE",1);
	$thaw = undef;
	eval $result2->{Registry}->{object}; #sets thaw
	is(scalar keys %{$thaw->{name2coll}}, 1);
	ok(defined $thaw->{name2coll}->{TestAutoDB_2});
	
	# passing create=0 flag should not add collection and throws an error
	require 'TestAutoDB_1.pm';
	my ($autodb3, $exception);
	try {
	    	$autodb3 = Class::AutoDB->new(
	                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
	                          -user=>$DBConnector::DB_USER,
	                          -password=>$DBConnector::DB_PASS,
	                          -create=>0
	                        );
	   return;
	}
	catch Error with {
	  $exception = shift;   # Get hold of the exception object
	};

	ok($exception =~ /-create=>0/, "create=0 throws exception when storage is attempted");
	my $result3 = $DBH->selectall_hashref("select * from $OBJECT_TABLE",1);
	$thaw = undef;
	eval $result3->{Registry}->{object}; #sets thaw
	is(scalar keys %{$thaw->{name2coll}}, 1);
	ok(!defined $thaw->{name2coll}->{TestAutoDB_1}, 'no change with create=0 set');
	ok(defined $thaw->{name2coll}->{TestAutoDB_2}, 'but existing object table is unaffected');
}


