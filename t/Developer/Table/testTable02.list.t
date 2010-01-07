use t::lib;
use strict;
use Test::More;
use Class::AutoDB::ListTable;

# Test Class::AutoDB::ListTable
# Simple black box testing of the interface

sub do_test {
  my($testname,$name,$keys,$create,$index)=@_;
  my @args;
  push(@args,(-name=>$name)) if $name;
  push(@args,(-keys=>$keys)) if $keys;
  push(@args,(-index=>$index)) if defined $index;
  my $table=new Class::AutoDB::ListTable(@args);
  ok($table,"$testname: new");
  is($table->name,$name,"$testname: name");
  my %t_keys=$table->keys;
  my $t_keys=$table->keys;
  is_deeply(\%t_keys,$keys||{},"$testname: keys as HASH");
  is_deeply($t_keys,$keys||{},"$testname: keys as HASH ref");
  if ($name) {
    my @t_create=$table->create;
    my $t_create=$table->create;
    ok_create(\@t_create,$create,"$testname: create as ARRAY");
    ok_create($t_create,$create,"$testname: create as ARRAY ref");
    
    my $drop=qq(drop table if exists $name);
    my @t_drop=$table->drop;
    my $t_drop=$table->drop;
    ok_drop(\@t_drop,$drop,"$testname: drop as ARRAY");
    ok_drop($t_drop,$drop,"$testname: drop as ARRAY ref");
  }
  $table;
}
sub ok_create {
  my($t_sql,$sql,$label)=@_;
  $t_sql=join(' ',@$t_sql);	# should only have one SQL statement
  is(norm_create($t_sql),norm_create($sql),$label);
}
sub ok_drop {
  my($t_sql,$sql,$label)=@_;
  $t_sql=join(' ',@$t_sql);	# should only have one SQL statement
  is(norm_drop($t_sql),norm_drop($sql),$label);
}
sub norm_create {
  my($sql)=@_;
  return undef unless $sql=~/\S/; # empty string
  $sql=~s/\s+/ /g;		   # convert all whitespace to single spaces
  my($create_table,$name,$cols,$rest)=
    $sql=~/^\s*(create table) (\w+)\s*\(\s*(.*)\s*\)\s*(.*)$/i;
  my $norm="$create_table $name";
  my @coldefs=sort split(/\s*,\s*/,$cols);
  $norm.='('.join(',',@coldefs).')';
  $norm=norm_keywords($norm);
  "$norm$rest";
}
sub norm_drop {
  my($sql)=@_;
  return undef unless $sql=~/\S/; # empty string
  $sql=~s/\s+/ /g;		   # convert all whitespace to single spaces
  my $norm;
  my($drop_table,$if_exists,$name,$rest)=$sql=~/^\s*(drop table) (if exists) (\w+)\s*(.*)$/i;
  my $norm="$drop_table $if_exists $name";
  $norm=norm_keywords($norm);
  "$norm$rest";
}
sub norm_keywords {
  my($sql)=@_;
  $sql=~s/\b(create table)\b/\U$1/i;
  $sql=~s/\b(drop table)\b/\U$1/i;
  $sql=~s/\b(primary key)\b/\U$1/i;
  $sql=~s/\b(index)\b/\U$1/gi;
  $sql=~s/\b(bigint)\b/\U$1/gi;
  $sql=~s/\b(unsigned)\b/\U$1/gi;
  $sql=~s/\b(not null)\b/\U$1/gi;
  $sql=~s/\b(int)\b/\U$1/gi;
  $sql=~s/\b(double)\b/\U$1/gi;
  $sql=~s/\b(longtext)\b/\U$1/gi;
  $sql=~s/\b(if exists)\b/\U$1/gi;
  $sql=~s/\b(add)\b/\U$1/gi;
  $sql;
}

my $table=do_test('empty table');
my $table=do_test
  ('table with name and string key',
   'Person_key1',
   {key1=>'string'},
   q(create table Person_key1
     (oid bigint unsigned not null, key1 longtext, index(oid), index(key1(255)))),
  );  
my $table=do_test
  ('table with name and integer key',
   'Person_key1',
   {key1=>'integer'},
   q(create table Person_key1
     (oid bigint unsigned not null, key1 int, index(oid), index(key1))),
  );
my $table=do_test
  ('table with name and float key',
   'Person_key1',
   {key1=>'float'},
   q(create table Person_key1
     (oid bigint unsigned not null, key1 double, index(oid), index(key1))),
  );
my $table=do_test
  ('table with name and object key',
   'Person_key1',
   {key1=>'object'},
   q(create table Person_key1
     (oid bigint unsigned not null, key1 bigint unsigned, index(oid), index(key1))),
  );

done_testing();
