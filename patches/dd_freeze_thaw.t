package DD_test;
use lib qw(../blib/lib ../blib/arch);
use Data::Dumper;
use Test::More qw/no_plan/;

$Data::Dumper::Useperl = 1;
my $DUMPER=new Data::Dumper([undef],['thaw']) ->
  Purity(1)->Indent(1)->Freezer('DUMPER_freeze')->Toaster('DUMPER_thaw');

my $f = new freezable;
my $t = new unthawable;

$f->{_OTHER} = new unthawable;
$t->{_OTHER} = new freezable;

my ($thaw);

print "-" x 100, "\n"; 
print "Freezable\n";
print "-" x 100, "\n"; 
my $th = $DUMPER->Values([$f])->Dump;
#print Dumper $th;
eval $th; #sets $thaw
#print Dumper $thaw; 
isa_ok($thaw,'freezable');
is($thaw->oid, 1);
isnt($thaw->can('DUMPER_thaw'),undef);
is($thaw->{_OTHER}->oid, 3);
is($thaw->{_OTHER}->can('DUMPER_thaw'),undef);
undef $thaw;

print "-" x 100, "\n";
print "Unfreezable\n";
print "-" x 100, "\n";

my $th2 = $DUMPER->Values([$t])->Dump; #sets $thaw
#print Dumper $th2;
eval $th2; #sets $thaw
#print Dumper $thaw;
is($thaw->oid, 3);
is($thaw->can('DUMPER_thaw'),undef);
is($thaw->{_OTHER}->oid, 1);
isnt($thaw->{_OTHER}->can('DUMPER_thaw'),undef);

## freezable package
package freezable;

sub new {
  my($self)=@_;
  return bless {}, $self; 
}

sub oid {
 return 1; 
}

sub DUMPER_freeze {
  my($self)=@_;
  print ">>> DUMPER_freeze ",$self->oid,"\n";
  $self->{_OID} = $self->oid;
  $self->{_CLASS} = ref $self;
  return $self;
}

sub DUMPER_thaw {
  my($self)=@_;
  print "<<< DUMPER_thaw ", $self->oid, "\n";
  return $self;
}

sub oid2object {
  shift @_ unless ref($_[0])=~/DBI::/;
  %__PACKAGE__::OID_2_OBJECT=shift @_ if @_;
  return \%$__PACKAGE__::OID_2_OBJECT;
}

## unthawable package (no DUMPER_freeze, DUMPER_thaw method)
package unthawable;

sub new {
  my($self)=@_;
  return bless {_OID=>$self->oid,_CLASS=>$self}, $self; 
}

sub oid {
 return 3; 
}
