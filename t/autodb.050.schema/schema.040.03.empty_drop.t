########################################
# test various settings of 'drop': param missing, or set to undef, 0, or 1
# driver must call each test with arg 'setup' then with arg 'test'
# this set (00, 01, ...) starts with empty database
########################################
use t::lib;
use strict;
use Test::More;

use Class::AutoDB;
use schemaUtil; use Person;
my $labelprefix='drop=>1';

my($action)=@ARGV;
if ($action=~/^s/i) {
  report_pass(drop_all(),"$labelprefix: database empty");
} elsif ($action=~/^t/i) {
  my $autodb=eval {new Class::AutoDB(database=>'test',drop=>1)};
  is($@,'',"$labelprefix: new");
  my $correct_tables=correct_tables();
  ok_dbtables($correct_tables,"$labelprefix: tables");
  my $correct_columns=correct_columns();
  ok_dbcolumns($correct_columns,"$labelprefix: columns");
} else {
  fail("test requires 'action' parameter to be 'setup' or 'test'");
}

done_testing();

