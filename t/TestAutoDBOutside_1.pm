package TestAutoDBOutside_1;

# test package that is completely outside the Class::Auto* scheme

use lib qw(. t ../lib);
use strict;

sub new {
  return bless {}, shift;
}

sub this {
  @_>1?
     $_[0]->{this}=$_[1] : 
     $_[0]->{this};   
}

sub that {
  @_>1?
     $_[0]->{that}=$_[1] : 
     $_[0]->{that};   
}

sub other {
  @_>1?
     $_[0]->{other}=$_[1] : 
     $_[0]->{other};   
}

1;
