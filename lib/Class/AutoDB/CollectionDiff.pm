package Class::AutoDB::CollectionDiff;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Collection;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

BEGIN {
  @AUTO_ATTRIBUTES=qw(baseline other
		      baseline_only new_keys same_keys inconsistent_keys
		      );
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);
}
sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my($baseline,$other)=$self->get(qw(baseline other));
  $self->warn("CollectionDiff needs two collections") unless (keys %$args == 2);
  my($baseline_only,$new_keys,$same_keys,$inconsistent_keys);
  my $baseline_keys=$baseline->keys || {};
  my $other_keys=$other->keys || {};
  while(my($key,$type)=each %$baseline_keys) {
    my $other_type=$other_keys->{$key};
    if (defined $other_type) {
      if ($type eq $other_type) {
	$same_keys->{$key}=$type;
      } elsif ($type ne $other_type) {
	$inconsistent_keys->{$key}=[$type,$other_type];
      } else {
	$self->warn("Key $key fell through classification");
      }
    } else {			#  !defined $other_key
      $baseline_only->{$key}=$type;
    }
  }
  while(my($key,$other_type)=each %$other_keys) {
    $new_keys->{$key}=$other_type unless defined $baseline_keys->{$key};
  }

  $self->baseline_only($baseline_only || {});
  $self->new_keys($new_keys || {});
  $self->same_keys($same_keys || {});
  $self->inconsistent_keys($inconsistent_keys || {});
}
sub is_consistent {
  %{$_[0]->inconsistent_keys}==0 ? 1 : 0;
}
sub is_inconsistent {
  %{$_[0]->inconsistent_keys}>0 ? 1 : 0;
}
sub is_equivalent {
  my($self)=@_;
  my $baseline_keys=$self->baseline->keys || {};
  my $other_keys=$self->other->keys || {};
  %{$self->same_keys}==%$baseline_keys && %$baseline_keys==%$other_keys ? 1 : 0;
}
sub is_different {
  !$_[0]->is_equivalent;
}
sub is_sub {
 $_[0]->is_consistent && %{$_[0]->new_keys}==0 ? 1 : 0;
}
sub is_super {
  $_[0]->is_consistent && %{$_[0]->baseline_only}==0 ? 1 : 0;
}
sub is_expanded {
 %{$_[0]->new_keys}>0 ? 1 : 0;
}

1;

__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::CollectionDiff - Compare two collection definitions and maintain differences

=head1 SYNOPSIS

Used by Class::AutoDB::RegistryDiff to process differences between
in-memory and saved registriies

  use Class::AutoDB::CollectionDiff;
  use Class::AutoDB::Collection;
  my $diff=new Class::AutoDB::CollectionDiff(-baseline=>$saved,-change=>$in_memory)
  if ($diff->is_sub) {                     # is new collection subset of saved one?
    $registry=$saved_registry;             # then used saved one
  } elsif  ($diff->is_different) {
    # get changes -- new collections and collections with new columns
    my %new_keys=$diff->new_keys;
    my @expanded_collections=$diff->expanded_collections;
    # process changes
  }

=head1 DESCRIPTION

This class compares two collection definitions and records their
differences.  The first collection is considered the baseline, and
differences are reported relative to it.

=head2 Methods

 Title   : new
 Usage   : $diff=new Class::AutoDB::CollectionDiff(-baseline=>$saved,-other=>$in_memory)
 Function: Compare two collections and remember differences
 Returns : Object recording differences
 Args    : -baseline	baseline collection
           -other	new collection being compared to baseline

 Title   : new_keys
 Usage   : $keys=$diff->new_keys;
 Function: Return keys=>type pairs for keys present in new collection, but not baseline
 Args    : None
 Returns : hash or HASH ref of key=>type pairs

 Title   : inconsistent_keys
 Usage   : $key_errors=$diff->inconsistent_keys
 Function: Return keys that are present in both collections with different types
 Args    : None
 Returns : hash or HASH ref of key=>[baseline_type,new_type]

 Title   : is_consistent
 Usage   : $bool=$diff->is_consistent
 Function: Check if collections are consistent
 Args    : None
 Returns : true/false values

 Title   : is_inconsistent
 Usage   : $bool=$diff->is_inconsistent
 Function: Check if collections are inconsistent
 Args    : collection being compared with this one
s Returns : true/false values

 Title   : is_equivalent
 Usage   : $bool=$diff->is_equivalent
 Function: Check if collections are equivalent.
 Args    : None
 Returns : true/false values

 Title   : is_different
 Usage   : $bool=$diff->is_different
 Function: Checkif collections are not equivalent.
 Args    : None
 Returns : true/false values

 Title   : is_sub
 Usage   : $bool=$collection->is_sub
 Function: Check if new collection is subset of baseline.  Note: equivalent is 
           considered subset.
 Args    : None
 Returns : true/false values

 Title   : is_super
 Usage   : $bool=$diff->is_super
 Function: Check if new collection is superset of baseline. Note: equivalent is 
           considered subset.
 Args    : None
 Returns : true/false values

 Title   : is_expanded
 Usage   : $bool=$collection->has_new
 Function: Check if new collection has new keys relative to baseline
 Args    : None
 Returns : true/false values

=cut
