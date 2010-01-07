package Class::AutoDB::Serialize;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Globals;
use Class::AutoDB::Oid;
use DBI;
use Carp;
#use Scalar::Util qw(weaken);
use Scalar::Util qw(refaddr);
use Class::AutoDB::Dumper;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!
@OTHER_ATTRIBUTES=qw(oid dbh);
Class::AutoClass::declare(__PACKAGE__);

my $DUMPER=new Class::AutoDB::Dumper([undef],['thaw']) ->
  Purity(1)->Indent(1)->
  Freezer('DUMPER_freeze')->Toaster('DUMPER_thaw');

my $GLOBALS=Class::AutoDB::Globals->instance();
my $OID2OBJ=$GLOBALS->oid2obj;
my $OBJ2OID=$GLOBALS->obj2oid;
my $OID_GEN=int rand 1<<30;	# 2**30
my $REGISTRY_OID=$GLOBALS->registry_oid;

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  # NG 09-12-19: removed ->oid for cleanup of user-object namespace. 
  #              only needed for registry
  # my $oid=$self->oid || $$.$OID_GEN++;
  my $oid=ref $self eq 'Class::AutoDB::Registry'? $REGISTRY_OID: $$.$OID_GEN++;
  oid2obj($oid,$self);
  obj2oid($self,$oid);
}
sub DUMPER_freeze {
  my($self)=@_;
  my $oid=$OBJ2OID->{refaddr $self};
  #print ">>> DUMPER_freeze ->$oid<- ($self)\n";

  # NG 09-12-08: code below is on the right track, but still broken
  # to revert back to old Data::Dumper, 
  #   mysql: delete * from _AutoDB;
  #   ~/local/lib/perl/x86_64-linux-thread-multi/Data: mv Dumper.pm Dumper.pm.new
#   if ($Data::Dumper::VERSION >= 2.122) { # have to modify object itself
#     %$self=(_OID=>$oid,_CLASS=>ref $self);
#     bless $self,'Class::AutoDB::Oid';
#     return $self;
#   }
  return bless {_OID=>$oid,_CLASS=>ref $self},'Class::AutoDB::Oid';
}
sub oid2obj {			# allow call as object or class method, or function
  shift if $_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0],__PACKAGE__);
  my $oid=shift;
  @_? $OID2OBJ->{$oid}=$_[0]: $OID2OBJ->{$oid};
}
sub obj2oid {			# allow call as class method or function
  shift unless ref $_[0];
  my $obj=shift;
  #print ">>>>>>>>>> obj2oid on $obj\n";
  @_? $OBJ2OID->{refaddr $obj}=$_[0]: $OBJ2OID->{refaddr $obj};
}
*oid=\&obj2oid;

sub dbh {
  my $self=shift;
  $GLOBALS->dbh(@_);
}
sub store {
  my($self,$transients)=@_;
  $DUMPER->Reset;
  # Make a shallow copy, replacing independent objects with stored reps
  my $copy={_CLASS=>ref $self};
  while(my($key,$value)=each %$self) {
    # NG 09-12-05: fixed wrong regex. Scary this wasn't caught earlier!!
    # next if grep /$key/,@$transients;
    next if grep {$_ eq $key} @$transients;
    # NG 06-05-16: fixed bug. UNIVERSAL::isa reports true if arg is __name__
    #              of Serialize subclass. here, we only want true case if arg
    #              __object__ whose class is Serialize subclass
    if (UNIVERSAL::isa(ref $value,__PACKAGE__)) {
      $copy->{$key}=$value->DUMPER_freeze;
    } else {
      $copy->{$key}=$value;
    }
  }
  my $freeze=$DUMPER->Values([$copy])->Dump;
  really_store($self,$freeze);
  #  TODO: weaken($OID2OBJ->{$oid});
  $self;
}
sub fetch {			# allow call as object or class method, or function
  shift if $_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0],__PACKAGE__);
  my($oid)=@_;
  # three cases: (1) new oid, (2) Oid exists, (3) real object exists
  my $obj=$OID2OBJ->{$oid};
  if (!defined $obj) {		                                # case 1
    $obj=really_fetch($oid) || return undef;
    $OID2OBJ->{$oid}=$obj;
    $OBJ2OID->{refaddr $obj}=$oid;
#   weaken($OID2OBJ->{$oid});
  } elsif (UNIVERSAL::isa($obj,'Class::AutoDB::Oid')) { # case 2
    $obj=really_fetch($oid,$obj) || return undef;
  }		                        # case 3 -- nothing more to do
  $obj;
}
# used by 'get' methods in Cursor
sub thaw {			# allow call as object or class method, or function
  shift if $_[0] eq __PACKAGE__ || UNIVERSAL::isa($_[0],__PACKAGE__);
  my($oid,$freeze)=@_;
  # three cases: (1) new oid, (2) Oid exists, (3) real object exists
  my $obj=$OID2OBJ->{$oid};
  if (!$obj) {		                                # case 1
    $obj=really_thaw($oid,$obj,$freeze) || return undef;
    $OID2OBJ->{$oid}=$obj;
    $OBJ2OID->{refaddr $obj}=$oid;
#   weaken($OID2OBJ->{$oid});
  } elsif (UNIVERSAL::isa($obj,'Class::AutoDB::Oid')) { # case 2
    $obj=really_thaw($oid,$obj,$freeze) || return undef;
  }				                        # case 3 -- nothing more to do
  $obj;
}

sub really_store {
  my($self,$freeze)=@_;
  my($sth,$ret);
  my $dbh=$GLOBALS->dbh;
  # NG 09-12-19: removed ->oid for cleanup of user-object namespace. 
  #              cases other than first not needed anyway (I hope!!)
  # my $oid = obj2oid($self) || $self->oid || $OBJ2OID->{refaddr $self};
  my $oid=obj2oid($self);
  #print ">>> storing  ->$oid<-($self)", ref $self, "\n";
#  $sth=$dbh->prepare(qq(insert into _AutoDB(oid,object) values (?,?)));

  $sth=$dbh->prepare(qq(REPLACE INTO _AutoDB(oid,object) VALUES (?,?)));

  $sth->bind_param(1,$oid);
  $sth->bind_param(2,$freeze);
  $ret=$sth->execute or confess $sth->errstr;
}
sub really_fetch {
  my($oid,$obj)=@_;
  my($sth,$ret);
  my $dbh=$GLOBALS->dbh;
  $sth=$dbh->prepare(qq(select object from _AutoDB where oid=?));
  $sth->bind_param(1,$oid);
  $ret=$sth->execute or confess $sth->errstr;
  # get id of new object
  my($freeze)=$sth->fetchrow_array;
  # NG 10-01-01: moved errstr check up from 'unless' below. since unless now commented out
  confess $sth->errstr if $sth->err;
  # unless ($freeze) {
    # confess $sth->errstr if $sth->err;
    # my $class=$obj->{_CLASS};
    # NG 10-01-01: moved error check from really_fetch to really_thaw because there
    #              aer other ways of getting here
    # NG 06-05-16: changed warn to confess. calling routine dies immediately anyway
    #              and confess output easier to catch in eval
    # confess qq/Trying to deserialize an instance of class $class with oid \'$oid\'. Ensure that: 
    # \t 1) The object was serialized correctly (you may have forgotten to call put() on it). 
    # \t 2) You can connect to the data source in which it has been serialized.\n/;
    # warn qq/Trying to deserialize an instance of class $class with oid \'$oid\'. Ensure that: 
    # \t 1) The object was serialized correctly (you may have forgotten to call put() on it). 
    # \t 2) You can connect to the data source in which it has been serialized.\n/;
    # return undef;
  # }
  really_thaw($oid,$obj,$freeze);
}
sub really_thaw {
  my($oid,$obj,$freeze)=@_;
  # NG 10-01-01: moved error check from really_fetch to really_thaw because there
  #              aer other ways of getting here
  # NG 06-05-16: changed warn to confess. calling routine dies immediately anyway
  #              and confess output easier to catch in eval
   unless ($freeze) {
     my $class=$obj->{_CLASS};
     confess qq/Trying to deserialize an instance of class $class with oid \'$oid\'. Ensure that: 
    \t 1) The object was serialized correctly (you may have forgotten to call put() on it). 
    \t 2) You can connect to the data source in which it has been serialized.
    \t 3) The object was serialized correctly\n/;
   }
  my $thaw;			# variable used in $DUMPER
  eval $freeze;			# sets $thaw
  # if the thawed structure is circular and refers to the present object,
  # the act of thawing will have created an Oid for the present object.
  # if so, use it.
  defined $obj or $obj=oid2obj($oid);
  # remove Oid attributes from thawed object and Oid if it exists
  my $class=$thaw->{_CLASS};
  delete @$thaw{qw(_CLASS _OID)}; 
  delete @$obj{qw(_CLASS _OID)} if defined $obj;
  defined $obj or $obj={};
  # copy data back from thawed structure to obj. this leaves embedded Oids un-fetched 
  @$obj{keys %$thaw}=values %$thaw;
  # bless $obj (or rebless Oid) to real class
  # NG 06-10-31: fix old bug: use class if necessary -- scary this wasn't caught before
  # use object's class if not already done. Body of code same as AUTOLOAD. 
  # TODO: refactor someday
  no strict 'refs';

  # NG 09-01-14: fixed dumb ass bug: the eval "use..." below is, of course, not run 
  #   if the class is already loaded.  This means that the value of $@ is not reset
  #   by the eval.  So, if it had a true value before the eval, it will have the 
  #   same value afterwards causing the error code to be run!
  #   FIX: changed "use" to "require" (which returns true on success) and use the
  #   return value to control whether error code run
  # eval "use $class" unless ${$class.'::'}{AUTODB};
  unless (${$class.'::'}{AUTODB}) {
    eval "require $class" or die $@;
  }
  bless $obj,$class;
}

sub DESTROY {
#  my($self)=@_;
#  return unless $self->oid;
#  delete $self->OID2OBJ->{$self->oid}; # have to get a fresh copy next time
}

1;
