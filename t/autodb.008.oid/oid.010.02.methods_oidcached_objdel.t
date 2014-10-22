########################################
# this series tests Oid methods 
# this script tests the case in which objects do not exist in database
########################################
use t::lib;
use strict;
use Carp;
use Test::More;
use Test::Deep;
use autodbUtil;

use Persistent;

tie_oid;
my $dbh=DBI->connect("dbi:mysql:database=test",undef,undef,
		     {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,});
is($DBI::errstr,undef,'connect');
Class::AutoDB::Serialize->dbh($dbh);

my @ids=keys %id2oid;;
my @oids=values %id2oid;
my @objs=map {conjure_oid($_,'Oid','Persistent')} @oids;
my $oids=join(', ',@oids);

# delete objects from database by setting object=NULL. note that some may already be deleted
$dbh->do(qq(UPDATE _AutoDB SET object=NULL WHERE oid IN ($oids)));
report_fail(!$dbh->err,$dbh->errstr);

# make sure it really happened
my($count)=$dbh->selectrow_array
  (qq(SELECT COUNT(oid) FROM _AutoDB WHERE oid IN ($oids) AND object IS NULL;));
ok($count==scalar @oids,'objects deleted from database by setting object=NULL');

# NG 10-09-16: decided some time ago to remove is_extant, is_deleted, del to avoid polluting 
#              namespace further, but just now getting around to fixing tests
# Oid methods are oid, put. make sure these don't hit AUTOLOAD
# # Oid methods are is_extant, is_deleted, put, del. make sure these don't hit AUTOLOAD
my $i=0; my $obj=$objs[$i]; my $oid=$oids[$i];
my $actual=eval{$obj->oid;};
report_fail($@ eq '',$@,__FILE__,__LINE__);
is($actual,$oid,'oid method returned correct value');
ok_objcache($obj,$oid,'Oid','Persistent','oid method did not fetch object',__FILE__,__LINE__);

# $i++; my $obj=$objs[$i]; my $oid=$oids[$i];
# my $actual=eval{$obj->is_extant;};
# report_fail($@ eq '',$@,__FILE__,__LINE__);
# ok(!$actual,'is_extant method returned correct value (false)');
# ok_objcache($obj,$oid,'OidDeleted','Persistent','is_extant method fetched object as OidDeleted',
# 	    __FILE__,__LINE__);

# $i++; my $obj=$objs[$i]; my $oid=$oids[$i];
# my $actual=eval{$obj->is_deleted;};
# report_fail($@ eq '',$@,__FILE__,__LINE__);
# ok($actual,'is_deleted method returned correct value (true)');
# ok_objcache($obj,$oid,'OidDeleted','Persistent','is_deleted method fetched object as OidDeleted',
# 	    __FILE__,__LINE__);

$i++; my $obj=$objs[$i]; my $oid=$oids[$i];
my $actual=eval{$obj->put;};		# should be nop.
report_fail($@ eq '',$@,__FILE__,__LINE__);
is($actual,undef,'put method returned correct value (undef)');
ok_objcache($obj,$oid,'Oid','Persistent','put method did not fetch object',__FILE__,__LINE__);
# NG 10-09-16: check database after 'put' to make sure it's really a nop
my($count)=$dbh->selectrow_array
  (qq(SELECT COUNT(oid) FROM _AutoDB WHERE oid=$oid AND object IS NULL;));
report_fail(!$dbh->err,$dbh->errstr,__FILE__,__LINE__);
is($count,1,'put method was nop on database');

# $i++; my $obj=$objs[$i]; my $oid=$oids[$i];
# my $actual=eval{$obj->del;};	# should actually delete the object...
# report_fail($@ eq '',$@,__FILE__,__LINE__);
# is($actual,1,'del method returned correct value (1)');
# ok_objcache($obj,$oid,'OidDeleted','Persistent','del method deleted object in memory',
# 	    __FILE__,__LINE__);

# now call application method. should confess
$i++; my $obj=$objs[$i]; my $oid=$oids[$i];
my $actual=eval{$obj->name;};
if ($@) {
  like($@,qr/Trying to access deleted object of class \(unknown\) via method name/,
       'application method confessed with the expected message');
} else {
  report_fail(0,"application method was supposed to confess but did not",__FILE__,__LINE__);
}
ok_objcache($obj,$oid,'OidDeleted','Persistent',
	    'application method (name) fetched object as OidDeleted',__FILE__,__LINE__);

done_testing();

