use lib qw(. t ../lib);
use strict;
use Class::AutoDB::SmartProxy;
use Test::More qw/no_plan/;
use Data::Dumper; # only for debugging
use DBConnector;
use Class::AutoDB;
use Class::AutoDB::WeakCache;
use Thing;

my $DBC = new DBConnector;
my $dbh = $DBC->getDBHandle;

SKIP: {
        skip "! Cannot test without a database connection - please adjust DBConnector.pm's connection parameters and \'make test\' again", 1 unless $DBC->can_connect;
 
  my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        ); 
                        
  my $SmartProxy = Thing->new();
  
  is(CORE::ref($SmartProxy), 'Class::AutoDB::SmartProxy', 'SmartProxy object is proxying for instantiated class');
  is(ref($SmartProxy), 'Thing', qq/ref operatator is overloaded to retrun the proxied-for (instantiated) object's name/);
  is($SmartProxy->{__state}, 'new', 'SmartProxy state=new for unstored object');
  is($SmartProxy->{__proxy_for}, 'Thing','SmartProxy is proxying for the instantiated class');
  
  # freezing will persist SmartProxy object in data store as serialized (by Data::Dumper)
  # strings that can be eval'd into living, breathing objects (exist as $thaw=[serialized string])
  $SmartProxy->freeze;
  my $dbh = $autodb->dbh;
  my $thaw;
  
  # serialized data
  my $sd_result = $dbh->selectall_arrayref("select * from $Class::AutoDB::Registry::OBJECT_TABLE");
  my $registry = $sd_result->[0]->[1];
  eval $registry; # sets $thaw variable
  is(CORE::ref($thaw->{name2coll}->{Thing}), 'Class::AutoDB::Collection', 'registry contains the correct collection and is written to database');
  is(ref($thaw->{name2coll}->{Thing}), 'Class::AutoDB::Collection', 'overridden ref operator only lies about non-SmartProxy classes');
  my $so = $sd_result->[1]->[1]; # serialized object
  eval $so; # sets $thaw variable
  is(CORE::ref($thaw), 'Class::AutoDB::SmartProxy', 'reconstituted object is really a Class::AutoDB::SmartProxy instance');
  is(ref($thaw), 'Thing', 'but overloaded ref operator lies to you :)');
  
  # search keys
  my $sk_result = $dbh->selectall_arrayref('select * from Thing');
  ok($sk_result->[0]->[0] =~ /[0-9]+/, 'SmartProxy inserted into database with valid ID');
  is($sk_result->[0]->[1], undef, 'search key is undef (expected)');
  is($sk_result->[0]->[2], undef, 'search key is undef (expected)');
}