use Util;
use Bio::ISB::AutoDB::Registration;
use Bio::ISB::AutoDB::Collection;
use Bio::ISB::AutoDB::CollectionDiff;
use strict;
$|=1;

my $r=new Bio::ISB::AutoDB::Registration (-keys=>qq());
my $empty=new Bio::ISB::AutoDB::Collection(-name=>'empty');
$empty->register($r);

my $r=new Bio::ISB::AutoDB::Registration (-keys=>qq(a string));
my $a=new Bio::ISB::AutoDB::Collection(-name=>'a');
$a->register($r);

my $r=new Bio::ISB::AutoDB::Registration (-keys=>qq(a string, b string));
my $ab=new Bio::ISB::AutoDB::Collection(-name=>'ab');
$ab->register($r);

my $r=new Bio::ISB::AutoDB::Registration (-keys=>qq(b string, c string));
my $bc=new Bio::ISB::AutoDB::Collection(-name=>'bc');
$bc->register($r);

my $r=new Bio::ISB::AutoDB::Registration (-keys=>qq(b string, a object, d string));
my $bad=new Bio::ISB::AutoDB::Collection(-name=>'bad');
$bad->register($r);

test($empty,$a);
test($a,$empty);

test($a,$ab);
test($ab,$a);

test($ab,$bc);
test($bc,$ab);

test($ab,$bad);
test($bad,$ab);

test($ab,$ab);

sub test {
  my($baseline,$other)=@_;
  print "\nComparing ",$baseline->name," vs. ",$other->name,"\n";
  my $diff=new Bio::ISB::AutoDB::CollectionDiff(-baseline=>$baseline,-other=>$other);
  print "is_consistent=",$diff->is_consistent,"\n";
  print "is_inconsistent=",$diff->is_inconsistent,"\n";
  print "is_equivalent=",$diff->is_equivalent,"\n";
  print "is_different=",$diff->is_different,"\n";
  print "is_sub=",$diff->is_sub,"\n";
  print "is_super=",$diff->is_super,"\n";
  print "is_expanded=",$diff->is_expanded,"\n";
  print "baseline_only=",join(', ',keys %{$diff->baseline_only}),"\n";
  print "new_keys=",join(', ',keys %{$diff->new_keys}),"\n";
  print "same_keys=",join(', ',keys %{$diff->same_keys}),"\n";
  print "inconsistent_keys=",join(', ',keys %{$diff->inconsistent_keys}),"\n";
}
