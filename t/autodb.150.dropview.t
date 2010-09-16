# Regression test: deal with views everywhere that we create or drop tables...

package Test;
use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES %AUTODB);
@AUTO_ATTRIBUTES=qw(name strings);
%AUTODB=1;
# %AUTODB=(collection=>'Test', 
# 	 keys=>qq(id integer, name strings));
Class::AutoClass::declare;

package main;
use t::lib;
use strict;
use Carp;
use Test::More;
use Test::Deep;
use Class::AutoDB;
use autodbUtil;

# create views that will get in the way
my $autodb=new Class::AutoDB(database=>'test',create=>1);
isa_ok($autodb,'Class::AutoDB','class is Class::AutoDB - sanity check');
my $dbh=$autodb->dbh;

# # need $dbh to do so.
# my $dbh=DBI->connect("dbi:mysql:database=test",undef,undef,
#                      {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,});
# report_fail(!$DBI::err,"connecting to MySQL: $DBI::errstr",__FILE__,__LINE__);
my @views=qw(Test Test_strings);
my $views=join(',',@views);
my @sql=map {(qq(DROP TABLE IF EXISTS $_),qq(DROP VIEW IF EXISTS $_),
	       qq(CREATE VIEW $_ AS SELECT 1 AS test))} @views;
map {$dbh->do($_)} @sql;
# make sure it worked 
my $tables=$dbh->selectcol_arrayref(qq(SHOW TABLES)); #  return ARRAY ref of table names
for my $view (@views) {
  my $ok=grep /^$view$/,@$tables;
  ok($ok,"view $view created");
}

# regression test starts here
# re-open $autodb in alter mode
my $autodb=new Class::AutoDB(database=>'test',alter=>1);
isa_ok($autodb,'Class::AutoDB','class is Class::AutoDB - sanity check');
# create
eval {$autodb->register(class=>'Test',collection=>'Test',keys=>qq(name string));};
my $ok=report_fail(!$@,"create failed: $@",__FILE__,__LINE__);
report_pass($ok,'create');
# alter
eval {$autodb->register(class=>'Test',collection=>'Test',keys=>qq(strings list(string)));};
my $ok=report_fail(!$@,"alter failed: $@",__FILE__,__LINE__);
report_pass($ok,'alter');

# make sure it worked by putting an object and checking database
my $object=new Test name=>'test',strings=>[qw(hello world)];
$autodb->put($object);
my($count)=$dbh->selectrow_array(qq(SELECT COUNT(*) FROM Test));
is($count,1,'number of rows in Test table');
my($count)=$dbh->selectrow_array(qq(SELECT COUNT(*) FROM Test_strings));
is($count,2,'number of rows in Test_strings table');
my $rows=$dbh->selectall_arrayref
  (qq(SELECT name,strings FROM Test NATURAL JOIN Test_strings));
my @correct=([qw(test hello)],[qw(test world)]);
cmp_deeply($rows,bag(@correct),'data in Test and Test_strings tables');

done_testing();
