##
## time test object creation and storage.
##
use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use TestAutoDB_1;
use Class::AutoDB;
use strict;
use constant MAX=>1000;
my($DBC, $DBH, $start_time, $log);

BEGIN {
 require 'DBConnector.pm';
 $DBC = new DBConnector;
 $DBH = $DBC->getDBHandle;
 $start_time = time();
}

is(1,1,"testing system performance");
$log = "t/.AUTODB_performance";
print "writing performance test to $log\n";

my $autodb =
  Class::AutoDB->new(
		  -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                  -user=>$DBConnector::DB_USER,
                  -password=>$DBConnector::DB_PASS
                );

for(1..MAX){
  # create objects in memory and populate the collection
  my $thingy=TestAutoDB_1->new(-this=>1, -that=>'thingy1', -other=>["one","two"]);
}
my $create_and_store_time = time() - $start_time;
# this will retrieve MAX collections
my $cursor = $autodb->find(-collection=>'TestAutoDB_1');
my $retrieve_time = time() - $start_time - $create_and_store_time;

END {
my $cleanup_time = time() - $start_time - $retrieve_time;
my $total_time = $create_and_store_time + $retrieve_time + $cleanup_time;

open(FILE, "+>>$log") || die "could not open $log: $!";
print FILE "-" x 80, "\n";
print FILE "AutoDB Version: ", $Class::AutoDB::VERSION, "\n";
print FILE "Testing with ", MAX, " objects\n";
print FILE "Date: ", `date`;
print FILE "-" x 80, "\n";
print FILE "time elapsed for creating, storing ==> $create_and_store_time\n";
print FILE "time elapsed for retrieving from database ==> $retrieve_time\n";
print FILE "time elapsed for destroying objects ==> $cleanup_time\n";
print FILE "total time elapsed ==> $total_time\n";
print FILE "\n";
}
