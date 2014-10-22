# Regression test: get multiple terms from list(object)
# there were separate bugs in the object vs. non-object cases. sigh...

package Test;
use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES %AUTODB);
@AUTO_ATTRIBUTES=qw(name id list);
%AUTODB=(collection=>'Test',keys=>qq(id integer, name string, list list(object)));
Class::AutoClass::declare;

sub _init_self {
 my ($self,$class,$args)=@_;
 return unless $class eq __PACKAGE__;    # to prevent subclasses from re-running this
 my $i=$args->i;
 $self->list([$i++,$i++]);
}

package main;
use t::lib;
use strict;
use Carp;
use Test::More;
use Test::Deep;
use Class::AutoDB;
use autodbUtil;

my $autodb=new Class::AutoDB(database=>'test',create=>1); # create database
isa_ok($autodb,'Class::AutoDB','class is Class::AutoDB - sanity check');

# regression test starts here
# make and store some objects. multi values set in _init_self
my $num_objects=3;
my @objects=map {new Test(i=>$_, name=>"test_multi $_",id=>id_next())} (0..$num_objects-1);
# set object lists
map {$objects[$_]->list([$objects[$_],$objects[($_+1)%$num_objects]])} (0..$num_objects-1);
$autodb->put_objects;

# check the data using SQL
my $dbh=$autodb->dbh;
my @oids=map {$autodb->oid($_)} @objects;
my($actual_count)=$dbh->selectrow_array
  (qq(SELECT COUNT(DISTINCT Test.oid) 
      FROM Test, Test_list AS L1, Test_list AS L2
      WHERE Test.oid=L1.oid AND Test.oid=L2.oid AND L1.list=$oids[1] AND L2.list=$oids[2]));
is($actual_count,1,'count via SQL: repeated key');

# check the data using AutoDB
my $actual_count=$autodb->count(collection=>'Test',list=>$objects[1],list=>$objects[2]);
is($actual_count,1,'count via AutoDB: repeated key');
my @actual_objects=$autodb->get(collection=>'Test',list=>$objects[1],list=>$objects[2]);
cmp_bag(\@actual_objects,[$objects[1]],'objects via AutoDB: repeated key');

# make sure we haven't broken non-repeated case
my($actual_count)=$dbh->selectrow_array
  (qq(SELECT COUNT(DISTINCT Test.oid) 
      FROM Test, Test_list AS L1, Test_list AS L2
      WHERE Test.oid=L1.oid AND Test.oid=L2.oid AND L1.list=$oids[1]));
is($actual_count,2,'count via SQL: non-repeated key');

my $actual_count=$autodb->count(collection=>'Test',list=>$objects[1]);
is($actual_count,2,'count via AutoDB: non-repeated key');
my @actual_objects=$autodb->get(collection=>'Test',list=>$objects[1]);
cmp_bag(\@actual_objects,[@objects[0,1]],'objects via AutoDB: non-repeated key');

done_testing();
