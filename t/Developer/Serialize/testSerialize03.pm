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
use overload
  fallback => 'TRUE';
1;
