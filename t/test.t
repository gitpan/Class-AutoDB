use Test::Harness;
use strict;
use lib qw(./t blib/lib);

# Driver for Class::AutoDB tests

# Note: testSerialize06a.multistore.t is deliberately being run several time
# because it tests repeated storage of the same objects

my @test_files=
  qw(
     t/testSerialize00.setup.t
     t/testSerialize01a.simple.t
     t/testSerialize01b.simple.t
     t/testSerialize02a.object.t
     t/testSerialize02b.object.t
     t/testSerialize03a.object.t
     t/testSerialize03b.object.t
     t/testSerialize04a.object.non.t
     t/testSerialize04b.object.non.t
     t/testSerialize05a.object.non.t
     t/testSerialize05b.object.non.t
     t/testSerialize06a.multistore.t
     t/testSerialize06a.multistore.t
     t/testSerialize06a.multistore.t
     t/testSerialize10a.graph.t
     t/testSerialize10b.graph.t
     t/testSerialize11a.big.t
     t/testSerialize11b.big.t
     t/testSerialize12a.person.t
     t/testSerialize12b.person.t
     t/testSerialize13a.foobar.t
     t/testSerialize13b.foobar.t

     t/testTable01.base.t  
     t/testTable02.list.t

     t/testCollection01.simple.t  
     t/testCollection02.merge.t
     t/testCollection03.alter.t
     t/testCollectionDiff01.t

     t/testRegistration01.t

     t/testRegistry00.setup.t
     t/testRegistry01.register.t
     t/testRegistry02.merge.t
     t/testRegistry03.schema.t
     t/testRegistry04a.persistent.t
     t/testRegistry04b.persistent.t
     t/testRegistry04c.persistent.t
     t/testRegistry04d.persistent.t
     t/testRegistry04e.persistent.t
     t/testRegistry04f.persistent.t
     t/testRegistry04g.persistent.t
     t/testRegistry04h.persistent.t
     t/testRegistry04i.persistent.t
     t/testRegistry04j.persistent.t

     t/testAutoDB00.setup.t
     t/testAutoDB01a.create.t
     t/testAutoDB01b.create.t
     t/testAutoDB01bb.create.t
     t/testAutoDB01c.create.t
     t/testAutoDB01cc.create.t
     t/testAutoDB01d.create.t
     t/testAutoDB01dd.create.t
     t/testAutoDB01e.create.t
     t/testAutoDB01ee.create.t
     t/testAutoDB01a.drop.t
     t/testAutoDB01b.drop.t
     t/testAutoDB01bb.drop.t
     t/testAutoDB01c.drop.t
     t/testAutoDB01cc.drop.t
     t/testAutoDB01d.drop.t
     t/testAutoDB01dd.drop.t
     t/testAutoDB01e.drop.t
     t/testAutoDB01ee.drop.t
     t/testAutoDB01a.alter.t
     t/testAutoDB01b.alter.t
     t/testAutoDB01bb.alter.t
     t/testAutoDB01c.alter.t
     t/testAutoDB01cc.alter.t
     t/testAutoDB01d.alter.t
     t/testAutoDB01dd.alter.t
     t/testAutoDB01e.alter.t
     t/testAutoDB01ee.alter.t
     t/testAutoDB01a.default_schema.t
     t/testAutoDB01b.default_schema.t
     t/testAutoDB01bb.default_schema.t
     t/testAutoDB01c.default_schema.t
     t/testAutoDB01cc.default_schema.t
     t/testAutoDB01d.default_schema.t
     t/testAutoDB01dd.default_schema.t
     t/testAutoDB01e.default_schema.t
     t/testAutoDB01ee.default_schema.t
     t/testAutoDB02a.create.t
     t/testAutoDB02b.create.t
     t/testAutoDB02bb.create.t
     t/testAutoDB02c.create.t
     t/testAutoDB02cc.create.t
     t/testAutoDB02d.create.t
     t/testAutoDB02dd.create.t
     t/testAutoDB02e.create.t
     t/testAutoDB02ee.create.t
     t/testAutoDB02a.drop.t
     t/testAutoDB02b.drop.t
     t/testAutoDB02bb.drop.t
     t/testAutoDB02c.drop.t
     t/testAutoDB02cc.drop.t
     t/testAutoDB02d.drop.t
     t/testAutoDB02dd.drop.t
     t/testAutoDB02e.drop.t
     t/testAutoDB02ee.drop.t
     t/testAutoDB02a.alter.t
     t/testAutoDB02b.alter.t
     t/testAutoDB02bb.alter.t
     t/testAutoDB02c.alter.t
     t/testAutoDB02cc.alter.t
     t/testAutoDB02d.alter.t
     t/testAutoDB02dd.alter.t
     t/testAutoDB02e.alter.t
     t/testAutoDB02ee.alter.t
     t/testAutoDB02a.alter.t
     t/testAutoDB02b.alter.t
     t/testAutoDB02bb.alter.t
     t/testAutoDB02c.alter.t
     t/testAutoDB02cc.alter.t
     t/testAutoDB02d.alter.t
     t/testAutoDB02dd.alter.t
     t/testAutoDB02e.alter.t
     t/testAutoDB02ee.alter.t

     t/testAutoDB00.setup.t
     t/testAutoDB02a.create.t
     t/testAutoDB02a.default_schema.t
     t/testAutoDB02b.default_schema.t
     t/testAutoDB02bb.default_schema.t
     t/testAutoDB02c.default_schema.t
     t/testAutoDB02cc.default_schema.t
     t/testAutoDB02d.default_schema.t
     t/testAutoDB02dd.default_schema.t
     t/testAutoDB02e.default_schema.t
     t/testAutoDB02ee.default_schema.t

     t/testAutoDB11a.find.t
     t/testAutoDB11b.find.t
     t/testAutoDB12a.put.t
     t/testAutoDB12b.find.t
     t/testAutoDB13a.put.t
     t/testAutoDB13b.find.t
     t/testAutoDB14a.put.t
     t/testAutoDB14b.find.t
     t/testAutoDB14c.put_all.t
     t/testAutoDB14d.find.t
     t/testAutoDB14e.count.t
     t/_cleanup
    );

$Test::Harness::switches='';	# turn off -w
runtests(@test_files);
