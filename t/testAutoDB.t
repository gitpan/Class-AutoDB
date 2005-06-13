use Test::Harness;
use strict;

# Driver for Class::AutoDB::AutoDB tests
# Note: testAutoDB02 alter tests are deliberately run several times
# to test repeated alterations of the same tables

my @test_files=
  qw(testAutoDB00.setup.t
     testAutoDB01a.create.t
     testAutoDB01b.create.t
     testAutoDB01bb.create.t
     testAutoDB01c.create.t
     testAutoDB01cc.create.t
     testAutoDB01d.create.t
     testAutoDB01dd.create.t
     testAutoDB01e.create.t
     testAutoDB01ee.create.t
     testAutoDB01a.drop.t
     testAutoDB01b.drop.t
     testAutoDB01bb.drop.t
     testAutoDB01c.drop.t
     testAutoDB01cc.drop.t
     testAutoDB01d.drop.t
     testAutoDB01dd.drop.t
     testAutoDB01e.drop.t
     testAutoDB01ee.drop.t
     testAutoDB01a.alter.t
     testAutoDB01b.alter.t
     testAutoDB01bb.alter.t
     testAutoDB01c.alter.t
     testAutoDB01cc.alter.t
     testAutoDB01d.alter.t
     testAutoDB01dd.alter.t
     testAutoDB01e.alter.t
     testAutoDB01ee.alter.t
     testAutoDB01a.default_schema.t
     testAutoDB01b.default_schema.t
     testAutoDB01bb.default_schema.t
     testAutoDB01c.default_schema.t
     testAutoDB01cc.default_schema.t
     testAutoDB01d.default_schema.t
     testAutoDB01dd.default_schema.t
     testAutoDB01e.default_schema.t
     testAutoDB01ee.default_schema.t
     testAutoDB02a.create.t
     testAutoDB02b.create.t
     testAutoDB02bb.create.t
     testAutoDB02c.create.t
     testAutoDB02cc.create.t
     testAutoDB02d.create.t
     testAutoDB02dd.create.t
     testAutoDB02e.create.t
     testAutoDB02ee.create.t
     testAutoDB02a.drop.t
     testAutoDB02b.drop.t
     testAutoDB02bb.drop.t
     testAutoDB02c.drop.t
     testAutoDB02cc.drop.t
     testAutoDB02d.drop.t
     testAutoDB02dd.drop.t
     testAutoDB02e.drop.t
     testAutoDB02ee.drop.t
     testAutoDB02a.alter.t
     testAutoDB02b.alter.t
     testAutoDB02bb.alter.t
     testAutoDB02c.alter.t
     testAutoDB02cc.alter.t
     testAutoDB02d.alter.t
     testAutoDB02dd.alter.t
     testAutoDB02e.alter.t
     testAutoDB02ee.alter.t
     testAutoDB02a.alter.t
     testAutoDB02b.alter.t
     testAutoDB02bb.alter.t
     testAutoDB02c.alter.t
     testAutoDB02cc.alter.t
     testAutoDB02d.alter.t
     testAutoDB02dd.alter.t
     testAutoDB02e.alter.t
     testAutoDB02ee.alter.t

     testAutoDB00.setup.t
     testAutoDB02a.create.t
     testAutoDB02a.default_schema.t
     testAutoDB02b.default_schema.t
     testAutoDB02bb.default_schema.t
     testAutoDB02c.default_schema.t
     testAutoDB02cc.default_schema.t
     testAutoDB02d.default_schema.t
     testAutoDB02dd.default_schema.t
     testAutoDB02e.default_schema.t
     testAutoDB02ee.default_schema.t

     testAutoDB11a.find.t
     testAutoDB11b.find.t
     testAutoDB12a.put.t
     testAutoDB12b.find.t
     testAutoDB13a.put.t
     testAutoDB13b.find.t
     testAutoDB14a.put.t
     testAutoDB14b.find.t
     testAutoDB14c.put_all.t
     testAutoDB14d.find.t
     testAutoDB14e.count.t
    );

$Test::Harness::switches='';	# turn off -w
runtests(@test_files);
