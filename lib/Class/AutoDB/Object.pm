package Class::AutoDB::Object;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Globals;
use Class::AutoDB::Serialize;
@ISA = qw(Class::AutoDB::Serialize);
@OTHER_ATTRIBUTES=qw();
Class::AutoClass::declare(__PACKAGE__);

my $GLOBALS=Class::AutoDB::Globals->instance();
sub __autodb {
  my $self=shift;
  $GLOBALS->autodb(@_);
}

sub put {
  my($self,$autodb)=@_;
  $autodb or $autodb=$self->__autodb;
  # NG 09-12-19: logic moved to AutoDB for cleanup of user-object namespace
  # my $transients=$autodb->registry->class2transients(ref $self);
  # my $collections=$autodb->registry->class2collections(ref $self);
  # my $oid=$self->oid;
  # $self->Class::AutoDB::Serialize::store($transients); # store the serialized form
  # my @sql=map {$_->put($self)} @$collections; # generate SQL to store object in collections
  # $autodb->do_sql(@sql);
  $autodb->put($self);
}
#sub transients {
#  my($self,$autodb)=@_;
#  $autodb or $autodb=$self->autodb;
#  $autodb->registry->class2transients(ref $self);
#}

####################
# NG 05-12-26: added to correct what I think is a bug in Perl's overload support.
#              when I added overloaded "" operation to Oid, it caused real objects
#              to complain that "" was overloaded but no method found. the problem
#              may be caused by objects that start life os Oids then are reblessed.
use overload
  fallback => 'TRUE';
####################
