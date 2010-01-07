use t::lib;
use strict;
use Test::More;
use Test::Deep;
use Class::AutoDB::Registration;

# Test Class::AutoDB::Registration
# Simple black box testing of the interface

sub do_test {
  my($testname,@args)=@_;
  my $args=new Hash::AutoHash::Args(@args);

  # Do all combinations of parameter forms that make sense
  # -collection=>string list of names
  #            =>ARRAY of names
  #            =>HASH of keys string
  #            =>HASH of name=>{key=>type}
  # -keys      =>undef (if -collections is HASH)
  #            =>string of 'key type' pairs
  #            =>ARRAY of names
  #            =>HASH of key=>type pairs
  # -transients=>string list of attributes
  #            =>ARRAY of attributes
  my %coll_param;
  $coll_param{string}=$args->coll_string; 
  $coll_param{array}=$args->coll_array; 
  $coll_param{hash_string}=$args->coll_hash_string; 
  $coll_param{hash_array}=$args->coll_hash_array; 
  $coll_param{hash_hash}=$args->coll_hash_hash; 
  my %keys_param;
  $keys_param{string}=$args->keys_string;
  $keys_param{hash}=$args->keys_hash;
  my %tran_param;
  $tran_param{string}=$args->tran_string; 
  $tran_param{array}=$args->tran_array; 

  my %args_done;		             # to avoid repeating tests
  my $any_coll=grep {$_} values %coll_param; # TRUE if any coll_param set
  my $any_keys=grep {$_} values %keys_param; # TRUE if any coll_param set
  while(my($coll_type,$coll_param)=each %coll_param) {
    next if $any_coll && !$coll_param;	     # skip empy colls unless all are empty
    while(my($keys_type,$keys_param)=each %keys_param) {
      while(my($tran_type,$tran_param)=each %tran_param) {
	if ($coll_type eq 'hash_hash') {
	  $keys_type='undef';
	  $keys_param=undef;
	} else {
	  next if $any_keys && !$keys_param; # skip empty keys unless all are empty
	}
	my @args;
	push(@args,(-class=>$args->class)) if $args->class;
	push(@args,(-collection=>$coll_param)) if $coll_param;
	push(@args,(-keys=>$keys_param)) if $keys_param;
	push(@args,(-transients=>$tran_param)) if $tran_param;
	next if $args_done{"@args"}++;
	my $actual=new Class::AutoDB::Registration(@args);
	isa_ok($actual,"Class::AutoDB::Registration",$testname);
	my $coll_correct=$args->coll_correct||$args->coll_hash_hash||{};
	my $keys_correct=$args->keys_correct ||
	  (scalar(keys %$coll_correct)==1) || $keys_param? ($args->keys_hash||{}): {};
	my $correct=methods(class=>$args->class||undef,
			    collection=>$coll_correct,
			    collections=>$coll_correct,
			    collnames=>bag(defined $args->coll_array? @{$args->coll_array}: ()),
			    keys=>$keys_correct,
			    transients=>bag(defined $args->tran_array? @{$args->tran_array}: ()));
	cmp_deeply($actual,$correct,
		   "$testname: coll=$coll_type/keys=$keys_type/tran=$tran_type");
      }}}
}

#goto skip;

do_test('empty');
do_test
  ('class',
   -class=>'Class');
do_test
  ('0 collection + 0 keys',
   -coll_string=>'',
   -coll_array=>[],
   -coll_hash_string=>{},
   -coll_hash_array=>{},
   -coll_hash_hash=>{},
   -keys_string=>'',
   -keys_hash=>{},
  );
do_test
  ('1 collection + 0 keys',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_correct=>{Coll1=>{}},
   -keys_string=>'',
   -keys_hash=>{},
  );
do_test
  ('2 collections + 0 keys',
   -coll_string=>'Coll1 Coll2',
   -coll_array=>['Coll1','Coll2'],
   -coll_correct=>{Coll1=>{},Coll2=>{}},
   -keys_string=>'',
   -keys_hash=>{},
  );

do_test
  ('0 collection + 1 key (string implicit)',
   -coll_string=>'',
   -coll_array=>[],
   -coll_hash_string=>{},
   -coll_hash_array=>{},
   -coll_hash_hash=>{},
   -keys_string=>'attr1',
   -keys_hash=>{attr1=>'string'},
  );
do_test
  ('1 collection + 1 key (string implicit)',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>'attr1'},
   -coll_hash_array=>{Coll1=>['attr1']},
   -coll_hash_hash=>{Coll1=>{attr1=>'string'}},
   -keys_string=>'attr1',
   -keys_hash=>{attr1=>'string'},
  );
do_test
  ('2 collections + 1 key (string implicit)',
   -coll_string=>'Coll1 Coll2',
   -coll_array=>['Coll1','Coll2'],
   -coll_hash_string=>{Coll1=>'attr1', Coll2=>'attr1'},
   -coll_hash_array=>{Coll1=>['attr1'],Coll2=>['attr1']},
   -coll_correct=>{Coll1=>{attr1=>'string'},
		   Coll2=>{attr1=>'string'},},
   -keys_string=>'attr1',
   -keys_hash=>{attr1=>'string'},
  );

do_test
  ('0 collections + 1 key string)',
   -coll_string=>'',
   -coll_array=>[],
   -coll_hash_string=>{},
   -coll_hash_array=>{},
   -coll_hash_hash=>{},
   -keys_string=>'attr1 string',
   -keys_hash=>{attr1=>'string'},
  );
do_test
  ('1 collection + 1 key string)',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>'attr1 string'},
   -coll_hash_array=>{Coll1=>['attr1']},
   -coll_hash_hash=>{Coll1=>{attr1=>'string'}},
   -keys_string=>'attr1 string',
   -keys_hash=>{attr1=>'string'},
  );
do_test
  ('2 collections + 1 key string)',
   -coll_string=>'Coll1 Coll2',
   -coll_array=>['Coll1','Coll2'],
   -coll_hash_string=>{Coll1=>'attr1 string', Coll2=>'attr1 string'},
   -coll_hash_array=>{Coll1=>['attr1'],Coll2=>['attr1']},
   -coll_hash_hash=>{Coll1=>{attr1=>'string'},
		     Coll2=>{attr1=>'string'},},
   -keys_string=>'attr1',
   -keys_hash=>{attr1=>'string'},
  );
my $keys_string=qq(attr1,attr2,attr3,attr4);
my $keys_array=[qw(attr1 attr2 attr3 attr4)];
my $keys_hash={attr1=>'string',attr2=>'string',attr3=>'string',attr4=>'string'};
do_test
  ('0 collections + many keys (string implicit)',
   -coll_string=>'',
   -coll_array=>[],
   -coll_hash_string=>{},
   -coll_hash_array=>{},
   -coll_hash_hash=>{},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );
do_test
  ('1 collection + many keys (string implicit)',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>$keys_string},
   -coll_hash_array=>{Coll1=>$keys_array},
   -coll_hash_hash=>{Coll1=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );
do_test
  ('2 collection + many keys (string implicit)',
   -coll_string=>'Coll1 Coll2',
   -coll_array=>['Coll1','Coll2'],
   -coll_hash_string=>{Coll1=>$keys_string,Coll2=>$keys_string},
   -coll_hash_array=>{Coll1=>$keys_array,Coll2=>$keys_array},
   -coll_hash_hash=>{Coll1=>$keys_hash,Coll2=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );

my $keys_string=qq(attr1 string, attr2 string, attr3 string, attr4 string);
do_test
  ('0 collection + many keys string)',
   -coll_string=>'',
   -coll_array=>[],
   -coll_hash_string=>{},
   -coll_hash_array=>{},
   -coll_hash_hash=>{},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );
do_test
  ('1 collection + many keys string)',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>$keys_string},
   -coll_hash_array=>{Coll1=>$keys_array},
   -coll_hash_hash=>{Coll1=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );
do_test
  ('2 collections + many keys string)',
   -coll_string=>'Coll1 Coll2',
   -coll_array=>['Coll1','Coll2'],
   -coll_hash_string=>{Coll1=>$keys_string,Coll2=>$keys_string},
   -coll_hash_array=>{Coll1=>$keys_array,Coll2=>$keys_array},
   -coll_hash_hash=>{Coll1=>$keys_hash,Coll2=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );

my $keys_string=qq(name string, dob integer, grade_avg float, significant_other object, friends list(object));
my $keys_hash= {name=>'string', dob=>'integer', grade_avg=>'float', significant_other=>'object', friends=>'list(object)'};
do_test
  ('0 collections + many keys',
   -coll_string=>'',
   -coll_array=>[],
   -coll_hash_string=>{},
   -coll_hash_hash=>{},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );
do_test
  ('1 collection + many keys',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>$keys_string},
   -coll_hash_hash=>{Coll1=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );
do_test
  ('2 collections + many keys',
   -coll_string=>'Coll1 Coll2',
   -coll_array=>['Coll1','Coll2'],
   -coll_hash_string=>{Coll1=>$keys_string,Coll2=>$keys_string},
   -coll_hash_hash=>{Coll1=>$keys_hash,Coll2=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
  );

# fiddle with separators in keys string
my $keys_string1=qq(name   string,dob integer ,grade_avg   float ,  significant_other object  ,   friends list ( object ) );
do_test
  ('1 collection + many keys (wierd seps)',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>$keys_string1},
   -coll_hash_hash=>{Coll1=>$keys_hash},
   -keys_string=>$keys_string1,
   -keys_hash=>$keys_hash,
  );
do_test
  ('class + 1 transients',
   -class=>'Class',
   -tran_string=>'tra1',
   -tran_array=>['tra1'],
  );
my $tran_string=qq(tra1 tra2 tra3 tra4 tra5 tra6 tra7 tra8 tra9);
my $tran_array=[qw(tra1 tra2 tra3 tra4 tra5 tra6 tra7 tra8 tra9)];
do_test
  ('class + many transients',
   -class=>'Class',
   -tran_string=>$tran_string,
   -tran_array=>$tran_array,
  );
# fiddle with separators in transients string
my $tran_string1=qq(tra1,tra2, tra3,  tra4 ,tra5 , tra6 ,  tra7  ,  tra8 tra9);
do_test
  ('class + many transients (wierd seps)',
   -class=>'Class',
   -tran_string=>$tran_string1,
   -tran_array=>$tran_array,
  );
do_test
  ('all params: 1 collection + 1 key',
   -class=>'Class',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>'attr1'},
   -coll_hash_array=>{Coll1=>['attr1']},
   -coll_hash_hash=>{Coll1=>{attr1=>'string'}},
   -keys_string=>'attr1',
   -keys_hash=>{attr1=>'string'},
   -tran_string=>$tran_string,
   -tran_array=>$tran_array,
  );
do_test
  ('all params: 1 collection + many keys',
   -class=>'Class',
   -coll_string=>'Coll1',
   -coll_array=>['Coll1'],
   -coll_hash_string=>{Coll1=>$keys_string},
   -coll_hash_hash=>{Coll1=>$keys_hash},
   -keys_string=>$keys_string,
   -keys_hash=>$keys_hash,
   -tran_string=>$tran_string,
   -tran_array=>$tran_array,
  );

done_testing();
