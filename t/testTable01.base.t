use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::BaseTable;

# Test Class::AutoDB::BaseTable
# Simple black box testing of the interface

sub test {
  my($testname,$name,$keys,$create,$alter)=@_;
  my @args;
  push(@args,(-name=>$name)) if $name;
  push(@args,(-keys=>$keys)) if $keys;
  my $table=new Class::AutoDB::BaseTable(@args);
  ok($table,"$testname: new");
  is($table->name,$name,"$testname: name");
  my %t_keys=$table->keys;
  my $t_keys=$table->keys;
  is_deeply(\%t_keys,$keys||{},"$testname: keys as HASH");
  is_deeply($t_keys,$keys||{},"$testname: keys as HASH ref");
  if ($name) {
    my @t_schema=$table->schema;
    my $t_schema=$table->schema;
    my @t_create=$table->schema('create');
    my $t_create=$table->schema('create');
    ok_create(\@t_schema,$create,"$testname: schema as ARRAY");
    ok_create($t_schema,$create,"$testname: schema as ARRAY ref");
    ok_create(\@t_create,$create,"$testname: schema('create') as ARRAY");
    ok_create($t_create,$create,"$testname: schema('create') as ARRAY ref");
    
    my $drop=qq(drop table if exists $name);
    my @t_drop=$table->schema('drop');
    my $t_drop=$table->schema('drop');
    ok_drop(\@t_drop,$drop,"$testname: schema('drop') as ARRAY");
    ok_drop($t_drop,$drop,"$testname: schema('drop') as ARRAY ref");

    my @t_alter=$table->schema('alter');
    my $t_alter=$table->schema('alter');
    ok_alter(\@t_alter,$alter,"$testname: schema('alter') as ARRAY");
    ok_alter($t_alter,$alter,"$testname: schema('alter') as ARRAY ref");
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
sub ok_alter {
  my($t_sql,$sql,$label)=@_;
  $t_sql=join(' ',@$t_sql);	# should only have one SQL statement
  is(norm_alter($t_sql),norm_alter($sql),$label);
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
sub norm_alter {
  my($sql)=@_;
  return undef unless $sql=~/\S/; # empty string
  $sql=~s/\s+/ /g;		   # convert all whitespace to single spaces
  my $norm;
  my($alter_table,$name,$cols)=
    $sql=~/^\s*(alter table) (\w+)\s*(.*)$/i;
  my $norm="$alter_table $name";
  my @coldefs=sort split(/\s*,\s*/,$cols);
  $norm.=' '.join(',',@coldefs);
  $norm=norm_keywords($norm);
  $norm;
}
sub norm_keywords {
  my($sql)=@_;
  $sql=~s/\b(create table)\b/\U$1/i;
  $sql=~s/\b(drop table)\b/\U$1/i;
  $sql=~s/\b(alter table)\b/\U$1/i;
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

my $table=test('empty table');
my $table=test
  ('table with name',
   'Person',
   undef,
   q(create table Person (oid bigint unsigned not null, primary key (oid))),
  );
my $table=test
  ('table with keys',
   undef,
   {name=>'string',dob=>'integer',grade_avg=>'float',friend=>'object'});
my $table=test
  ('table with name and keys',
   'Person',
   {name=>'string',dob=>'integer',grade_avg=>'float',friend=>'object'},
   q(create table Person
     (oid bigint unsigned not null, friend  bigint unsigned, name longtext, 
      grade_avg double, dob int,
      primary key (oid), index(friend), index(name(255)), index(grade_avg), index(dob))),
   q(alter table Person 
     add friend bigint unsigned, add name longtext, add grade_avg double, add dob int,
     add index(friend), add index(name(255)), add index(grade_avg), add index(dob)),
  );

my $table=test
  ('table with name and 2 keys of each type',
   'Person',
   {name=>'string',dob=>'integer',grade_avg=>'float',friend=>'object',
    key1=>'string',key2=>'integer',key3=>'float',key4=>'object'},
   q(create table Person
     (oid bigint unsigned not null, friend bigint unsigned, name longtext, 
      grade_avg double, dob int,
      key1 longtext, key2 int, key3 double, key4 bigint unsigned,
      primary key (oid), index(friend), index(name(255)), index(grade_avg), index(dob),
      index(key1(255)), index(key2), index(key3), index(key4))),
   q(alter table Person 
     add friend bigint unsigned, add name longtext, add grade_avg double, add dob int,
     add key1 longtext, add key2 int, add key3 double, add key4 bigint unsigned,
     add index(friend), add index(name(255)), add index(grade_avg), add index(dob),
     add index(key1(255)), add index(key2), add index(key3), add index(key4)),
  );

# Test boundary cases for keys
my $table=test
  ('table with name and 0 keys',
   'Person',
   {},
   q(create table Person (oid bigint unsigned not null, primary key (oid))),
  );
my $table=test
  ('table with name and 1 key',
   'Person',
   {key1=>'string'},
   q(create table Person
     (oid bigint unsigned not null, key1 longtext,
      primary key (oid), index(key1(255)))),
     q(alter table Person 
       add key1 longtext, 
       add index(key1(255)))
  );

my $table=test
  ('table with name and 2 keys',
   'Person',
   {key1=>'string',key2=>'string'},
   q(create table Person
     (oid bigint unsigned not null, key1 longtext, key2 longtext,
      primary key (oid), index(key1(255)), index(key2(255)))),
     q(alter table Person 
       add key1 longtext, add key2 longtext, 
       add index(key1(255)), add index(key2(255)))
    );

my $table=test
  ('table with name and 3 keys',
   'Person',
   {key1=>'string',key2=>'string',key3=>'string'},
   q(create table Person
     (oid bigint unsigned not null, key1 longtext, key2 longtext, key3 longtext,
      primary key (oid), index(key1(255)), index(key2(255)), index(key3(255)))),
   q(alter table Person 
     add key1 longtext, add key2 longtext, add key3 longtext, 
     add index(key1(255)), add index(key2(255)), add index(key3(255)))
  );



