package Class::AutoDB::Oid;
use Class::AutoDB::Serialize;
use Class::AutoDB::Globals;
use Scalar::Util qw(refaddr);

my $GLOBALS=Class::AutoDB::Globals->instance();
my $OID2OBJ=$GLOBALS->oid2obj;
my $OBJ2OID=$GLOBALS->obj2oid;

sub DUMPER_freeze {return $_[0];}
sub DUMPER_thaw {
  my($self)=@_;
  my $oid=$self->{_OID};
  #print "<<< Class::AutoDB::Oid::DUMPER_thaw $self ($oid)\n";  
  my $obj=$OID2OBJ->{$oid};
  return $obj if $obj;
  $OID2OBJ->{$oid}=$self;	# save for next time -- to preserve shared object structure
  $OBJ2OID->{refaddr $self}=$oid;
  $self;
}
use vars qw($AUTOLOAD);
sub AUTOLOAD {
  my $self=shift;
  my $method=$AUTOLOAD;
  $method=~s/^.*:://;             # strip class qualification
  return if $method eq 'DESTROY'; # the books say you should do this
  my $oid=$self->{_OID};
  my $obj=Class::AutoDB::Serialize::fetch($oid);
  return $obj->$method(@_);
}
