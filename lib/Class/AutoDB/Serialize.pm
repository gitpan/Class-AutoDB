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
use Data::Dumper;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!
@OTHER_ATTRIBUTES=qw(oid dbh);
Class::AutoClass::declare(__PACKAGE__);

my $DUMPER=new Data::Dumper([undef],['thaw']) ->
  Purity(1)->Indent(1)->
  Freezer('DUMPER_freeze')->Toaster('DUMPER_thaw');

my $GLOBALS=Class::AutoDB::Globals->instance();
my $OID2OBJ=$GLOBALS->oid2obj;
my $OBJ2OID=$GLOBALS->obj2oid;
my $OID_GEN=int rand 1<<30;	# 2**30

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my $oid=$self->oid || $$.$OID_GEN++;
  oid2obj($oid,$self);
  obj2oid($self,$oid);
}
sub DUMPER_freeze {
  my($self)=@_;
  my $oid=$OBJ2OID->{refaddr $self};
  #print ">>> DUMPER_freeze ->$oid<- ($self)\n";
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
  my($self)=@_;
  $DUMPER->Reset;
  # Make a shallow copy, replacing independent objects with stored reps
  my $copy={_CLASS=>ref $self};
  while(my($key,$value)=each %$self) {
    if (UNIVERSAL::isa($value,__PACKAGE__)) {
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
  if (!$obj) {		                                # case 1
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
  my $oid = obj2oid($self) || $self->oid || $OBJ2OID->{refaddr $self};
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
  unless ($freeze) {
    confess $sth->errstr if $sth->err;
    my $class=$obj->{_CLASS};
    warn qq/Trying to deserialize an instance of class $class with oid \'$oid\'. Ensure that: 
    \t 1) The object was serialized correctly (you may have forgotten to call put() on it). 
    \t 2) You can connect to the data source in which it has been serialized.\n/;
    return undef;
  }
  really_thaw($oid,$obj,$freeze);
}
sub really_thaw {
  my($oid,$obj,$freeze)=@_;
  my $thaw;			# variable used in $DUMPER
  eval $freeze;			# sets $thaw
  # if the thawed structure is circular and refers to the present object,
  # the act of thawing will have created an Oid for the present object.
  # if so, use it.
  $obj or $obj=oid2obj($oid);
  # remove Oid attributes from thawed object and Oid if it exists
  my $class=$thaw->{_CLASS};
  delete @$thaw{qw(_CLASS _OID)}; 
  delete @$obj{qw(_CLASS _OID)} if $obj;
  $obj or $obj={};
  # copy data back from thawed structure to obj. this leaves embedded Oids un-fetched 
  @$obj{keys %$thaw}=values %$thaw;
  # bless $obj (or rebless Oid) to real class
  bless $obj,$class;
}

sub DESTROY {
#  my($self)=@_;
#  return unless $self->oid;
#  delete $self->OID2OBJ->{$self->oid}; # have to get a fresh copy next time
}

1;

__END__

=head1 NAME

Class::AutoDB::Serialize - Serialization engine for Class::AutoDB --
MySQL only for now

=head1 SYNOPSIS

This is a mixin class that enables objects to be serialized and stored
in a database as independent entities, and later fetched one-by-one or
in groups. Whether fetched individually or in groups, the original
shared object structure is preserved. It's not necessary for the object
to also from Class::AutoClass, although the examples here all do.

=head2 Define class that inherits from Class::AutoDB::Serialize

Person class with attributes 'name', 'sex', 'hobbies', and 'friends',
where 'friends' is a list of Persons.

 package Person;
 use Class::AutoClass;
 use Class::AutoDB::Serialize;
 @ISA=qw(Class::AutoClass Class::AutoDB::Serialize); 
 
 @AUTO_ATTRIBUTES=qw(name sex hobbies friends);
 @OTHER_ATTRIBUTES=qw();
 %SYNONYMS=();
 Class::AutoClass::declare(__PACKAGE__);
 1;

=head2 Create and store some objects

 use DBI;
 use Class::AutoDB::Serialize;
 use Person;
 my $dbh=DBI->connect('dbi:mysql:database=ngoodman;host=localhost');
 Class::AutoDB::Serialize->dbh($dbh);
 
 my $joe=new Person(-name=>'Joe',-sex=>'male',
                    -hobbies=>['mountain climbing', 'sailing']);
 my $mary=new Person(-name=>'Mary',-sex=>'female',
                     -hobbies=>['hang gliding']);
 my $bill=new Person(-name=>'Bill',-sex=>'male',
                     -hobbies=>['cooking', 'eating', 'sleeping']);
 # Set up friends lists
 $joe->friends([$mary,$bill]);
 $mary->friends([$joe,$bill]);
 $bill->friends([$joe,$mary]);
 
 # Store the objects
 $joe->store;
 $mary->store;
 $bill->store;
 
 # Print their object id's so you can fetch them later
 for my $obj ($joe, $mary, $bill) {
   print 'name=', $obj->name, ' oid=', $obj->oid, "\n";
 }

=head2 Fetch the objects

Assume that the oid's are passed as command line arguments

 my @oids=@ARGV;
 my $joe=Class::AutoDB::Serialize::fetch($ARGV[0]);
 my $mary=Class::AutoDB::Serialize::fetch($ARGV[1]);
 my $bill=Class::AutoDB::Serialize::fetch($ARGV[2]);
 # Print the objects' attributes
 for my $obj ($joe, $mary, $bill) {
   print 'oid=', $obj->oid, "\n";
   print 'name=', $obj->name, "\n";
   print 'sex=', $obj->sex, "\n";
   print 'hobbies=', join(', ',@{$obj->hobbies}), "\n";
   print 'friends=',"\n";
 for my $friend (@{$obj->friends}) {
   print ' oid=', $friend->oid, ', ';
   print 'name=', $friend->name, "\n";
 }
 print "----------\n";
 }
 # Change an attribute in each object to demonstrate 
 # that shared structure is preserved
 for my $obj ($joe, $mary, $bill) {
   $obj->name($obj->name.' Changed');
 }
 for my $obj ($joe, $mary, $bill) {
   print 'oid=', $obj->oid, "\n";
   print 'changed name=', $obj->name, "\n";
   print 'friends=',"\n";
   for my $friend (@{$obj->friends}) {
     print ' oid=', $friend->oid, ', ';
     print 'changed name=', $friend->name, "\n";
   }
   print "----------\n";
 }

=head1 DESCRIPTION

This is a mixin class that implements the serialization and data
storage engine for Class::AutoDB. Objects that inherit from this class
can be serialized and stored in a database as independent entities.
This only works for objects implemented as HASHes in the usual Perl
way.

What distinguishes Class::AutoDB::Serialize from the many other
excellent Perl serialization packages (eg, Data::Dumper, Storable,
YAML) is that we serialize objects as independent entities existing
within a large network, rather than serializing entire networks as a
whole. When an object is being serialized, other
E<ldquo>auto-serializableE<rdquo> objects that are encountered are not
serialized then and there; instead a placeholder object called an Oid
(short for I<object identifier>) is emitted into the serialization
stream. When the object is later fetched, the placeholders are not
immediately fetched; instead each placeholder is fetched transparently
when the program invokes a method on it (this is accomplished via an
AUTOLOAD mechanism).

The purpose of all this is to make it easy for Perl programs to operate
on large databases of objects. Objects can be created, stored, and
later fetched. If the object points to other objects, they will be
fetched when needed. New objects can be created, connected to the
network of existing objects, and stored.

=head1 BUGS and WISH-LIST

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Serialize.html#bugs_and_wishlist>


=head1 METHODS and FUNCTIONS - Initialization

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Serialize.html#methods_and_functions>

=cut
