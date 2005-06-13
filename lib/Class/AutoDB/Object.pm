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
sub autodb {
  my $self=shift;
  $GLOBALS->autodb(@_);
}

sub put {
  my($self,$autodb)=@_;
  $self->Class::AutoDB::Serialize::store; # store the serialized form
  $autodb or $autodb=$self->autodb;
  my $collections=$autodb->registry->class2colls(ref $self);
  my $oid=$self->oid;
  my @sql=map {$_->put($self)} @$collections; # generate SQL to store object in collections
  $autodb->do_sql(@sql);
}
