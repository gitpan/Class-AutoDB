use lib qw(./t blib/lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::Registration;
use Class::AutoDB::CollectionDiff;
use Class::AutoDB::Collection;


# Test Class::AutoDB::Collection
# Test methods that use CollectionDiffs.  Logically, should be run after testCollectionDiff01.t

sub do_test {
  my($testname,$baseline,$other_register,$keys)=@_;
  my $other=new Class::AutoDB::Collection(-name=>'Other',-register=>$other_register);
  my $diff=new Class::AutoDB::CollectionDiff(-baseline=>$baseline,-other=>$other);

  my @t_alter=$baseline->alter($diff);
  my $t_alter=$baseline->alter($diff);
  ok_alter($baseline->name,\@t_alter,$diff,"$testname: alter as ARRAY");
  ok_alter($baseline->name,$t_alter,$diff,"$testname: alter as ARRAY ref");
  $baseline;
}
# Very meager test.  Just makes tests counts
# TODO: improve this test
sub ok_alter {
  my($name,$t_alter,$diff,$label)=@_;
  # parse out the new tables and columns from the SQL
  my %t_new_tables;
  my %t_new_cols;
  for my $sql (@$t_alter) {
    next unless $sql=~/\S/;		# skip blank statements
    $sql=~s/\s+/ /g;
    if ($sql=~/^\s*create table/i) {
      my($tablename)=$sql=~/create table (\w+)/i;
      $t_new_tables{$tablename}=$sql;
    } elsif ($sql=~/alter table/i) {
      my($tablename,$cols)=$sql=~/^\s*alter table (\w+)\s*(.*)$/i;
      die unless $tablename eq $name; # only the base table can be altered
      my @coldefs=split(/\s*,\s*/,$cols);
      for my $coldef (@coldefs) {
	next if $coldef=~/^\s*add index/;
	my($colname)=$coldef=~/^\s*add (\w+)/;
	$t_new_cols{$colname}=$coldef;
      }
    }
  }
  # determine the new tables and columns from the CollectionDiff
  my $new_keys=$diff->new_keys;
  my %new_tables;
  my %new_cols;
  while(my($key,$type)=each %$new_keys) {
    if ($type=~/list\s*\(.*\)/i) {
      $new_tables{$name."_$key"}=$type;
    } else {
      $new_cols{$key}=$type;
    }
  }
  is_deeply([keys %t_new_tables],[keys %new_tables],"$label: new tables");
  is_deeply([keys %t_new_cols],[keys %new_cols],"$label: new columns");
} 

# Tests start here
# Start with no registrations and add in new ones
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 0 keys',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration'),
   {},
);
my $collection=do_test
  ('collection alter 1 scalar key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $collection=do_test
  ('collection alter 2 scalar keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );
my $collection=do_test
  ('collection alter 3 scalar keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
my $collection=do_test
  ('collection alter 4 scalar keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );
my $collection=do_test
  ('collection alter 1 list key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)'},
  );
my $collection=do_test
  ('collection alter 2 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $collection=do_test
  ('collection alter 3 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $collection=do_test
  ('collection alter 4 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
    lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Start over with no registrations and add in new ones
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 1 scalar and 1 list key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string,
	     lkey1 list(string))),
   {skey1=>'string',
    lkey1=>'list(string)'},
  );
my $collection=do_test
  ('collection alter 2 scalar and 2 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string,
	     lkey1 list(string), lkey2 list(string))),
  {skey1=>'string',skey2=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $collection=do_test
  ('collection alter 3 scalar and 3 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $collection=do_test
  ('collection alter 4 scalar and 4 list keys',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Do it again, starting from scratch each time
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 0 keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration'),
   {},
);
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 1 scalar key (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 2 scalar keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 3 scalar keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 4 scalar keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string)),
   {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 1 list key (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string))),
   {lkey1=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 2 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 3 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 4 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 1 scalar and 1 list key',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string,
	     lkey1 list(string))),
   {skey1=>'string',
    lkey1=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 2 scalar and 2 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string,
	     lkey1 list(string), lkey2 list(string))),
  {skey1=>'string',skey2=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 3 scalar and 3 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)'},
  );
my $baseline=new Class::AutoDB::Collection(-name=>'baseline');
my $collection=do_test
  ('collection alter 4 scalar and 4 list keys (from scratch)',
   $baseline,
   new Class::AutoDB::Registration
   (-class=>'Registration',
    -keys=>q(skey1 string, skey2 string, skey3 string, skey4 string,
	     lkey1 list(string), lkey2 list(string), lkey3 list(string), lkey4 list(string))),
  {skey1=>'string',skey2=>'string',skey3=>'string',skey4=>'string',
   lkey1=>'list(string)',lkey2=>'list(string)',lkey3=>'list(string)',lkey4=>'list(string)'},
  );

# Test some special cases
my $baseline=new Class::AutoDB::Collection
  (-name=>'baseline',
   -register=>new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)));
my $collection=do_test
  ('collection alter identical scalar key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey1 string)),
   {skey1=>'string'},
  );
my $collection=do_test
  ('collection alter disjoint scalar key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(skey2 string)),
   {skey1=>'string',skey2=>'string'},
  );

my $baseline=new Class::AutoDB::Collection
  (-name=>'baseline',
   -register=>new Class::AutoDB::Registration(-class=>'Registration',
					      -keys=>q(lkey1 list(string))));
my $collection=do_test
  ('collection alter identical list key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(lkey1 list(string))),
   {lkey1=>'list(string)'},
  );
my $collection=do_test
  ('collection alter disjoint list key',
   $baseline,
   new Class::AutoDB::Registration(-class=>'Registration',-keys=>q(lkey2 list(string))),
   {lkey1=>'list(string)',lkey2=>'list(string)'},
  );
