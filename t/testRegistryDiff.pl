use Util;
use Bio::ISB::AutoDB::Registration;
use Bio::ISB::AutoDB::Collection;
use Bio::ISB::AutoDB::RegistryDiff;
use strict;
$|=1;


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

test2($null,$empty);
test2($empty,$empty_a);
test2($empty_a,$empty_a_ab);
test2($empty_a_ab,$empty_a_bc);
test2($empty_a_ab,$empty_a_bad1);
test2($bad1,$bad2);
test2($empty_a_bad1,$empty_a_bad2);
test2($empty_a_expand1,$empty_a_expand2);
test2($empty_a_ab_bad1_expand1,$ab_bc_bad2_expand2);

sub make_registry {
  my $registry=new Bio::ISB::AutoDB::Registry;
  for my $hash (@_) {
    $registry->register(%$hash);
  }
  $registry;
}
sub test2 {
  my($a,$b)=@_;
  test($a,$b);
  test($b,$a);
}

sub test {
  my($baseline,$other)=@_;
  print "\nComparing ",coll_id($baseline)," vs. ",coll_id($other),"\n";
  my $diff=new Bio::ISB::AutoDB::RegistryDiff(-baseline=>$baseline,-other=>$other);
  print "is_consistent=",$diff->is_consistent,"\n";
  print "is_inconsistent=",$diff->is_inconsistent,"\n";
  print "is_equivalent=",$diff->is_equivalent,"\n";
  print "is_different=",$diff->is_different,"\n";
  print "is_sub=",$diff->is_sub,"\n";
  print "is_super=",$diff->is_super,"\n";
  print "has_new=",$diff->has_new,"\n";
  print "has_expanded=",$diff->has_expanded,"\n";
  print "baseline_only=",coll_names(@{$diff->baseline_only}),"\n";
  print "new_collections=",coll_names(@{$diff->new_collections}),"\n";
  print "equivalent_collections=",coll_names(@{$diff->equivalent_collections}),"\n";
  print "sub_collections=",coll_names(@{$diff->sub_collections}),"\n";
  print "super_collections=",coll_names(@{$diff->super_collections}),"\n";
  print "expanded_collections=",coll_names(@{$diff->expanded_collections}),"\n";
  print "inconsistent_collections=",coll_names(@{$diff->inconsistent_collections}),"\n";
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
