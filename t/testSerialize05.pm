package testSerialize;
use strict;
use Class::AutoDB::Serialize;
our @ISA=qw(Class::AutoDB::Serialize);

sub new {
  my $class=shift;
  my $self=__PACKAGE__->SUPER::new(); # initialize base classes
  my %args=@_;
  @$self{keys %args}=values %args;
  $self;
}
# need a method to force fetch of embedded Oids
sub nop {undef;}

1;

package testNonSerialize;
# Object that does not inherit from Class::AutoDB::Serialize

sub new {
  my $class=shift;
  my $self=bless {},$class;
  my %args=@_;
  @$self{keys %args}=values %args;
  $self;
}
# for compatibility with testSerialize. real nop!
sub nop {undef;}

1;
