use lib qw(. t ../lib);
use Test::More qw/no_plan/;
use Class::AutoDB;
use Class::AutoDB::Registry;
use Class::AutoDB::RegistryDiff;
use Class::AutoDB::Registration;
use DBI;
use IO::Scalar;
use strict;
use Data::Dumper; ## only for debugging

use vars qw($REGISTRY $REGISTRY_OID $OBJECT_TABLE $OBJECT_COLUMNS);
$REGISTRY_OID=1;		# object id for registry
$OBJECT_TABLE='_AutoDB';	# default for Object table
$OBJECT_COLUMNS=qq(id int not null auto_increment, primary key (id), object longblob);

# setup methods 
my %empty=(-collection=>'empty',-keys=>qq());
my %a=(-collection=>'a',-keys=>qq(a string));
my %ab=(-collection=>'ab',-keys=>qq(a string, b string));
my %bc=(-collection=>'bc',-keys=>qq(b string, c string));
my %bad1=(-collection=>'bad',-keys=>qq(b string, a string, d string));
my %bad2=(-collection=>'bad',-keys=>qq(b string, a object, d string));
my %expand1=(-collection=>'expand',-keys=>qq(a string, b string, c string));
my %expand2=(-collection=>'expand',-keys=>qq(b string, c string, d string));

my $null=make_registry();
my $empty=make_registry(\%empty);
my $empty_a=make_registry(\%empty,\%a);
my $empty_a_ab=make_registry(\%empty,\%a,\%ab);
my $empty_a_bc=make_registry(\%empty,\%a,\%bc);
my $bad1=make_registry(\%bad1);
my $bad2=make_registry(\%bad2);
my $empty_a_bad1=make_registry(\%empty,\%a,\%bad1);
my $empty_a_bad2=make_registry(\%empty,\%a,\%bad2);
my $empty_a_expand1=make_registry(\%empty,\%a,\%expand1);
my $empty_a_expand2=make_registry(\%empty,\%a,\%expand2);
my $empty_a_ab_bad1_expand1=make_registry(\%empty,\%a,\%ab,\%bad1,\%expand1);
my $ab_bc_bad2_expand2=make_registry(\%ab,\%bc,\%bad2,\%expand2);

# test isa
my $diff=new Class::AutoDB::RegistryDiff(-baseline=>$null,-other=>$null);
ok(ref($diff), "Class::AutoDB::RegistryDiff");
# test is_consistent
is(fdiff($null,$empty)->is_consistent,1,"testing is_consistent");
is(rdiff($null,$empty)->is_consistent,1);
is(fdiff($empty_a,$empty_a_ab)->is_consistent,1);
is(rdiff($empty_a,$empty_a_ab)->is_consistent,1);
is(fdiff($empty_a_ab,$empty_a_bc)->is_consistent,1);
is(rdiff($empty_a_ab,$empty_a_bc)->is_consistent,1); 
is(fdiff($empty_a_ab,$empty_a_bad1)->is_consistent,1);
is(rdiff($empty_a_ab,$empty_a_bad1)->is_consistent,1); 
is(fdiff($bad1,$bad2)->is_consistent,0);
is(rdiff($bad1,$bad2)->is_consistent,0);
is(fdiff($empty_a_bad1,$empty_a_bad2)->is_consistent,0);
is(rdiff($empty_a_bad1,$empty_a_bad2)->is_consistent,0);
is(fdiff($empty_a_expand1,$empty_a_expand2)->is_consistent,1);
is(rdiff($empty_a_expand1,$empty_a_expand2)->is_consistent,1);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_consistent,0);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_consistent,0);
is(rdiff($null,$null)->is_consistent,1);
is(fdiff($empty_a_ab_bad1_expand1,$empty_a_ab_bad1_expand1)->is_consistent,1);

# test is_inconsistent
is(fdiff($null,$empty)->is_inconsistent,0,"testing is_inconsistent");
is(rdiff($null,$empty)->is_inconsistent,0);
is(fdiff($empty_a,$empty_a_ab)->is_inconsistent,0);
is(rdiff($empty_a,$empty_a_ab)->is_inconsistent,0);
is(fdiff($empty_a_ab,$empty_a_bc)->is_inconsistent,0);
is(rdiff($empty_a_ab,$empty_a_bc)->is_inconsistent,0); 
is(fdiff($empty_a_ab,$empty_a_bad1)->is_inconsistent,0);
is(rdiff($empty_a_ab,$empty_a_bad1)->is_inconsistent,0); 
is(fdiff($bad1,$bad2)->is_inconsistent,1);
is(rdiff($bad1,$bad2)->is_inconsistent,1);
is(fdiff($empty_a_bad1,$empty_a_bad2)->is_inconsistent,1);
is(rdiff($empty_a_bad1,$empty_a_bad2)->is_inconsistent,1);
is(fdiff($empty_a_expand1,$empty_a_expand2)->is_inconsistent,0);
is(rdiff($empty_a_expand1,$empty_a_expand2)->is_inconsistent,0);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_inconsistent,1);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_inconsistent,1);
is(rdiff($null,$null)->is_inconsistent,0);
is(fdiff($empty_a_ab_bad1_expand1,$empty_a_ab_bad1_expand1)->is_inconsistent,0);

# test is_equivalent
is(fdiff($null,$empty)->is_equivalent,0,"testing is_equivalent");
is(rdiff($null,$empty)->is_equivalent,0);
is(fdiff($empty_a,$empty_a_ab)->is_equivalent,0);
is(rdiff($empty_a,$empty_a_ab)->is_equivalent,0);
is(fdiff($empty_a_ab,$empty_a_ab)->is_equivalent,1);
is(rdiff($empty_a_ab,$empty_a_ab)->is_equivalent,1); 
is(fdiff($empty_a_ab,$empty_a_bad1)->is_equivalent,0);
is(rdiff($empty_a_ab,$empty_a_bad1)->is_equivalent,0); 
is(fdiff($bad1,$bad2)->is_equivalent,0);
is(rdiff($bad1,$bad2)->is_equivalent,0);
is(fdiff($empty_a_bad1,$empty_a_bad2)->is_equivalent,0);
is(rdiff($empty_a_bad1,$empty_a_bad2)->is_equivalent,0);
is(fdiff($empty_a_expand1,$empty_a_expand2)->is_equivalent,0);
is(rdiff($empty_a_expand1,$empty_a_expand2)->is_equivalent,0);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_equivalent,0);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_equivalent,0);
is(rdiff($null,$null)->is_equivalent,1);
is(fdiff($empty_a_ab_bad1_expand1,$empty_a_ab_bad1_expand1)->is_equivalent,1);

# test is_different
is(fdiff($null,$empty)->is_different,1,"testing is_different");
is(rdiff($null,$empty)->is_different,1);
is(fdiff($empty_a,$empty_a_ab)->is_different,1);
is(rdiff($empty_a,$empty_a_ab)->is_different,1);
is(fdiff($empty_a_ab,$empty_a_bc)->is_different,1);
is(rdiff($empty_a_ab,$empty_a_bc)->is_different,1); 
is(fdiff($empty_a_ab,$empty_a_bad1)->is_different,1);
is(rdiff($empty_a_ab,$empty_a_bad1)->is_different,1); 
is(fdiff($bad1,$bad2)->is_different,1);
is(rdiff($bad1,$bad2)->is_different,1);
is(fdiff($empty_a_bad1,$empty_a_bad2)->is_different,1);
is(rdiff($empty_a_bad1,$empty_a_bad2)->is_different,1);
is(fdiff($empty_a_expand1,$empty_a_expand2)->is_different,1);
is(rdiff($empty_a_expand1,$empty_a_expand2)->is_different,1);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_different,1);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_different,1);
is(rdiff($null,$null)->is_different,0);
is(fdiff($bad1,$bad1)->is_different,0);

# test is_sub
is(fdiff($null,$empty)->is_sub,0,"testing is_sub");
is(rdiff($null,$empty)->is_sub,1);
is(fdiff($empty_a,$empty_a_ab)->is_sub,0);
is(rdiff($empty_a,$empty_a_ab)->is_sub,1);
is(fdiff($empty_a_ab,$empty_a_bc)->is_sub,0);
is(rdiff($empty_a_ab,$empty_a_bc)->is_sub,0); 
is(fdiff($empty_a_ab,$empty_a_bad1)->is_sub,0);
is(rdiff($empty_a_ab,$empty_a_bad1)->is_sub,0); 
is(fdiff($bad1,$bad2)->is_sub,0);
is(rdiff($bad1,$bad2)->is_sub,0);
is(fdiff($empty_a_bad1,$empty_a_bad2)->is_sub,0);
is(rdiff($empty_a_bad1,$empty_a_bad2)->is_sub,0);
is(fdiff($empty_a_expand1,$empty_a_expand2)->is_sub,0);
is(rdiff($empty_a_expand1,$empty_a_expand2)->is_sub,0);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_sub,0);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_sub,0);
is(rdiff($null,$null)->is_sub,1);
is(fdiff($bad1,$bad1)->is_sub,1);

# test is_super
is(fdiff($null,$empty)->is_super,1,"testing is_super");
is(rdiff($null,$empty)->is_super,0);
is(fdiff($empty_a,$empty_a_ab)->is_super,1);
is(rdiff($empty_a,$empty_a_ab)->is_super,0);
is(fdiff($empty_a_ab,$empty_a_bc)->is_super,0);
is(rdiff($empty_a_ab,$empty_a_bc)->is_super,0); 
is(fdiff($empty_a_ab,$empty_a_bad1)->is_super,0);
is(rdiff($empty_a_ab,$empty_a_bad1)->is_super,0); 
is(fdiff($bad1,$bad2)->is_super,0);
is(rdiff($bad1,$bad2)->is_super,0);
is(fdiff($empty_a_bad1,$empty_a_bad2)->is_super,0);
is(rdiff($empty_a_bad1,$empty_a_bad2)->is_super,0);
is(fdiff($empty_a_expand1,$empty_a_expand2)->is_super,0);
is(rdiff($empty_a_expand1,$empty_a_expand2)->is_super,0);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_super,0);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->is_super,0);
is(rdiff($null,$null)->is_super,1);
is(fdiff($bad1,$bad1)->is_super,1);

# test has_expanded
is(fdiff($null,$empty)->has_expanded,0,"testing has_expanded");
is(rdiff($null,$empty)->has_expanded,0);
is(fdiff($empty_a,$empty_a_ab)->has_expanded,0);
is(rdiff($empty_a,$empty_a_ab)->has_expanded,0);
is(fdiff($empty_a_ab,$empty_a_bc)->has_expanded,0);
is(rdiff($empty_a_ab,$empty_a_bc)->has_expanded,0); 
is(fdiff($empty_a_ab,$empty_a_bad1)->has_expanded,0);
is(rdiff($empty_a_ab,$empty_a_bad1)->has_expanded,0); 
is(fdiff($bad1,$bad2)->has_expanded,0);
is(rdiff($bad1,$bad2)->has_expanded,0);
is(fdiff($empty_a_bad1,$empty_a_bad2)->has_expanded,0);
is(rdiff($empty_a_bad1,$empty_a_bad2)->has_expanded,0);
is(fdiff($empty_a_expand1,$empty_a_expand2)->has_expanded,1);
is(rdiff($empty_a_expand1,$empty_a_expand2)->has_expanded,1);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->has_expanded,1);
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->has_expanded,1);
is(rdiff($null,$null)->has_expanded,0);
is(fdiff($bad1,$bad1)->has_expanded,0);

# test baseline_only
is(fdiff($null,$empty)->baseline_only->[0],undef, "testing baseline_only");
is(rdiff($null,$empty)->baseline_only->[0]->name,"empty");
is(fdiff($empty_a,$empty_a_ab)->baseline_only->[0], undef, "testing no unique baseline keys");
is(rdiff($empty_a,$empty_a_ab)->baseline_only->[0]->name,"ab");
is(fdiff($bad1,$bad2)->baseline_only->[0], undef);
is(rdiff($bad1,$bad2)->baseline_only->[0], undef);
is(fdiff($empty_a_expand1,$empty_a_expand2)->baseline_only->[0], undef);
is(fdiff($empty_a_expand1,$empty_a_expand2)->baseline_only->[0], undef);  
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->baseline_only->[0]->name,"a");
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->baseline_only->[1]->name,"empty");
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->baseline_only->[0]->name,"bc");
is(rdiff($null,$null)->baseline_only->[0],undef);

# test new_collections
is(fdiff($null,$empty)->new_collections->[0]->name,"empty","testing new_collections");
is(rdiff($null,$empty)->new_collections->[0], undef);
is(fdiff($empty_a,$empty_a_ab)->new_collections->[0]->name,"ab");
is(rdiff($empty_a,$empty_a_ab)->new_collections->[0], undef);
is(fdiff($bad1,$bad2)->new_collections->[0], undef);
is(rdiff($bad1,$bad2)->new_collections->[0], undef);
is(fdiff($empty_a_expand1,$empty_a_expand2)->new_collections->[0], undef);
is(fdiff($empty_a_expand1,$empty_a_expand2)->new_collections->[0], undef);  
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->new_collections->[0]->name,"bc");
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->new_collections->[0]->name,"a");
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->new_collections->[1]->name,"empty");
is(rdiff($null,$null)->new_collections->[0],undef);

# test equivalent_collections
is(fdiff($null,$empty)->equivalent_collections->[0], undef, "testing equivalent_collections");
is(rdiff($null,$empty)->equivalent_collections->[0], undef);
is(fdiff($empty_a,$empty_a_ab)->equivalent_collections->[0]->name,"a");
is(fdiff($empty_a,$empty_a_ab)->equivalent_collections->[1]->name,"empty");
is(fdiff($bad1,$bad2)->equivalent_collections->[0], undef);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->equivalent_collections->[0]->name,"ab");
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->equivalent_collections->[0]->name, "ab");
is(rdiff($null,$null)->equivalent_collections->[0],undef);

# test sub_collections
is(fdiff($null,$empty)->sub_collections->[0], undef, "testing sub_collections");
is(rdiff($null,$empty)->sub_collections->[0], undef);
is(fdiff($empty_a,$empty_a_ab)->sub_collections->[0]->name,"a");
is(fdiff($empty_a,$empty_a_ab)->sub_collections->[1]->name,"empty");
is(rdiff($empty_a,$empty_a_ab)->sub_collections->[0]->name, "a");
is(rdiff($empty_a,$empty_a_ab)->sub_collections->[1]->name,"empty");
is(fdiff($bad1,$bad2)->sub_collections->[0], undef);
is(rdiff($bad1,$bad2)->sub_collections->[0], undef);
is(rdiff($null,$null)->sub_collections->[0],undef);

# test super_collections
is(fdiff($null,$empty)->super_collections->[0], undef, "testing super_collections");
is(rdiff($null,$empty)->super_collections->[0], undef);
is(fdiff($empty_a,$empty_a_ab)->super_collections->[0]->name,"a");
is(fdiff($empty_a,$empty_a_ab)->super_collections->[1]->name,"empty");
is(rdiff($empty_a,$empty_a_ab)->super_collections->[0]->name, "a");
is(rdiff($empty_a,$empty_a_ab)->super_collections->[1]->name,"empty");
is(fdiff($bad1,$bad2)->super_collections->[0], undef);
is(rdiff($bad1,$bad2)->super_collections->[0], undef);
is(rdiff($null,$null)->super_collections->[0],undef);

# test_expanded_collections
is(fdiff($null,$empty)->expanded_collections->[0], undef, "testing expanded_collections");
is(rdiff($null,$empty)->expanded_collections->[0], undef);
is(fdiff($empty_a,$empty_a_ab)->expanded_collections->[0], undef);
is(fdiff($empty_a,$empty_a_ab)->expanded_collections->[0], undef);
is(fdiff($bad1,$bad2)->expanded_collections->[0], undef);
is(fdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->expanded_collections->[0]->name,"expand");
is(rdiff($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2)->expanded_collections->[0]->name, "expand");
is(rdiff($null,$null)->expanded_collections->[0],undef);

# test inconsistent_collections
is(fdiff($null,$empty)->inconsistent_collections->[0], undef ,"testing inconsistent_collections");
is(rdiff($null,$empty)->inconsistent_collections->[0], undef);
is(fdiff($bad1,$bad2)->inconsistent_collections->[0]->name,"bad");
is(rdiff($bad1,$bad2)->inconsistent_collections->[0]->name,"bad");
is(fdiff($empty_a,$empty_a_ab)->inconsistent_collections->[0], undef);
is(rdiff($empty_a,$empty_a_ab)->inconsistent_collections->[0], undef);
is(fdiff($empty_a_bad1,$empty_a_bad2)->inconsistent_collections->[0]->name,"bad");
is(rdiff($empty_a_bad1,$empty_a_bad2)->inconsistent_collections->[0]->name, "bad");
is(fdiff($bad1,$bad1)->inconsistent_collections->[0],undef);

# forward diff
sub fdiff{
 my($baseline,$other)=@_;
 return new Class::AutoDB::RegistryDiff(-baseline=>$baseline,-other=>$other);
}

#reverse diff
sub rdiff{
 my($baseline,$other)=@_;
 return new Class::AutoDB::RegistryDiff(-baseline=>$other,-other=>$baseline);
}

sub make_registry {
  my $registry=new Class::AutoDB::Registry;
  for my $hash (@_) {
    $registry->register(new Class::AutoClass::Args($hash));
  }
  $registry;
}

sub coll_id {
  my($registry)=@_;
  my @collections=$registry->collections;
  my @names;
  for my $collection (@collections) {
    my @keys=keys %{$collection->keys || {}};
    my $name=$collection->name.'('.join('',@keys).')';
    push(@names,$name);
  }
  join('/',@names);
}

sub coll_names {
  my @names=map {$_->name} @_;
  join(', ',,@names);
}
