package Class::AutoDB::RegistryDiff;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Data::Dumper;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Registry;
use Class::AutoDB::Collection;
use Class::AutoDB::CollectionDiff;
@ISA = qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(baseline other
    baseline_only new_collections
    equivalent_diffs sub_diffs super_diffs expanded_diffs inconsistent_diffs
    );
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
Class::AutoClass::declare(__PACKAGE__,\@AUTO_ATTRIBUTES,\%SYNONYMS);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my($baseline,$other)=$self->get(qw(baseline other));
  $self->throw("RegistryDiff needs two non-empty registries") unless ($baseline and $other);
  my($baseline_only,$new,$equivalent,$sub,$super,$expanded,$inconsistent);
  my $baseline_collections=$baseline->collections;
  for my $collection (@$baseline_collections) {
    my $name=$collection->name;
    my $other_collection=$other->collection($name);
    if (defined $other_collection) {
      my $diff=new Class::AutoDB::CollectionDiff(-baseline=>$collection,
						                             -other=>$other_collection);
      push(@$equivalent,$diff) if $diff->is_equivalent;
      push(@$sub,$diff) if $diff->is_sub;
      push(@$super,$diff) if $diff->is_super;
      push(@$expanded,$diff) if $diff->is_expanded;
      push(@$inconsistent,$diff) if $diff->is_inconsistent;
    } else { 
      push(@$baseline_only,$collection);
    }
  }
  my $other_collections=$other->collections;
  for my $collection (@$other_collections) {
    my $name=$collection->name;
    push(@$new,$collection) unless defined $baseline->collection($name);
  }
  $self->baseline_only($baseline_only || []);
  $self->new_collections($new || []);
  $self->equivalent_diffs($equivalent || []);
  $self->sub_diffs($sub || []);
  $self->super_diffs($super || []);
  $self->expanded_diffs($expanded || []);
  $self->inconsistent_diffs($inconsistent || []);
}

#sub baseline_only -- attribute
#sub new_collections -- attribute
sub equivalent_collections {
  $_[0]->_collections('equivalent_diffs');
}
sub sub_collections {
  $_[0]->_collections('sub_diffs');
}
sub super_collections {
  $_[0]->_collections('super_diffs');
}
sub expanded_collections {
  $_[0]->_collections('expanded_diffs');
}
sub inconsistent_collections {
  $_[0]->_collections('inconsistent_diffs');
}
sub _collections {
  my($self,$what_diffs)=@_;
  my $result; 
  @$result=map {$_->other} @{$_[0]->$what_diffs};
  $result;
}
sub is_consistent {
  @{$_[0]->inconsistent_diffs}==0 ? 1 : 0;
}
sub is_inconsistent {
  @{$_[0]->inconsistent_diffs}>0 ? 1 : 0;
}
sub is_equivalent {
  my($self)=@_;
  my $baseline_collections=$self->baseline->collections || [];
  my $other_collections=$self->other->collections || [];
  (@{$self->equivalent_diffs}==@$baseline_collections &&
    @$baseline_collections==@$other_collections) || 0;
}
sub is_different {
  $_[0]->is_equivalent==0 ? 1 : 0;
}
sub is_sub {
  my($self)=@_;
  my $other_collections=$self->other->collections || [];
  ($self->is_consistent && @{$self->sub_diffs}==@$other_collections) || 0;
}
sub is_super {
  my($self)=@_;
  my $baseline_collections=$self->baseline->collections || [];
  ($self->is_consistent && @{$self->super_diffs}==@$baseline_collections) || 0;
}
sub has_new {
  @{$_[0]->new_collections}>0 ? 1 : 0;
}
sub has_expanded {
  @{$_[0]->expanded_diffs}>0 ? 1 : 0;
}

1;

__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::RegistryDiff - Compare two registries and maintain differences

=head1 SYNOPSIS

Used by Class::AutoDB::Registry to process differences between
in-memory and saved registries.

  use Class::AutoDB::RegistryDiff;
  use Class::AutoDB::Registry;
  my $diff=new Class::AutoDB::RegistryDiff(-baseline=>$saved,-change=>$in_memory);
  if ($diff->is_sub) {                     # is new registry subset of saved one?
    $registry=$saved_registry;             # then used saved one
  } elsif  ($diff->is_different) {
    # get changes -- new collections and collections with new columns
    my @new_collections=$diff->new_collections;
    my @expanded_collections=$diff->expanded_collections;
    # process changes
  }

=head1 DESCRIPTION

This class compares two registries and records their differences.  The
first registry is considered the baseline, and differences are
reported relative to it.

=head2 Constructors

 Title   : new
 Usage   : $diff=new Class::AutoDB::RegistryDiff(-baseline=>$saved,-other=>$in_memory)
 Function: Compare registries and remember differences
 Returns : Object recording differences
 Args    : -baseline	baseline registry
           -other	new registry being compared to baseline

=head2 Methods to get Collections

 Title   : new_collections
 Usage   : $collections=$diff->new_collections;
 Function: Return collections present in new registry, but not baseline
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects

 Title   : expanded_collections
 Usage   : $collections=$diff->expanded_collections;
 Function: Return collections that have additional search keys in new registry 
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects

### TODO : should be called baseline_collectionss
 Title   : baseline_only
 Usage   : $collections=$diff->baseline_only
 Function: Return collections present in baseline registry, but not new one (return unique baseline collection)
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects

 Title   : equivalent_collections
 Usage   : $collections=$diff->equivalent_collections
 Function: Return collections present in both registries and unchanged in new one
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects

 Title   : sub_collections
 Usage   : $collections=$diff->sub_collections
 Function: Return collections that are present in both collections and are subcollections
           in new one relative to baseline
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects

 Title   : super_collections
 Usage   : $collections=$diff->super_collections
 Function: Return collections that are present in both collections and are supercollections
           in new one relative to baseline
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects

 Title   : insconsistent_collections
 Usage   : $collections=$diff->insconsistent_collections
 Function: Return collections that are present in both collections but  are insconsistent
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::Collection objects
 
=head2 Methods to get CollectionDiffs

 Title   : expanded_diffs
 Usage   : $diffs=$diff->expanded_diffs;
 Function: Return diffs for collections that have additional search keys in 
           new registry 
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::CollectionDiff objects

 Title   : equivalent_diffs
 Usage   : $diffs=$diff->equivalent_diffs
 Function: Return diffs for collections present in both registries and unchanged 
           in new one
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::CollectionDiff objects

 Title   : sub_diffs
 Usage   : $diffs=$diff->sub_diffs
 Function: Return diffs for collections that are present in both diffs and 
           are subcollections in new one relative to baseline
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::CollectionDiff objects

 Title   : super_diffs
 Usage   : $diffs=$diff->super_diffs
 Function: Return diffs for collections that are present in both diffs and 
           are supercollections in new one relative to baseline
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::CollectionDiff objects

 Title   : insconsistent_diffs
 Usage   : $diffs=$diff->insconsistent_diffs
 Function: Return diffs for collections that are present in both diffs but 
           are insconsistent
 Args    : None
 Returns : ARRAY ref of Class::AutoDB::CollectionDiff objects
 
=head2 Boolean test methods

 Title   : is_consistent
 Usage   : $bool=$diff->is_consistent
 Function: Check if registries are consistent
 Args    : None
 Returns : true/false values

 Title   : is_inconsistent
 Usage   : $bool=$diff->is_inconsistent
 Function: Check if registries are inconsistent
 Args    : registry being compared with this one
 Returns : true/false values

 Title   : is_equivalent
 Usage   : $bool=$diff->is_equivalent
 Function: Check if registries are equivalent.
 Args    : None
 Returns : true/false values

 Title   : is_different
 Usage   : $bool=$diff->is_different
 Function: Checkif registries are not equivalent.
 Args    : None
 Returns : true/false values

 Title   : is_sub
 Usage   : $bool=$registry->is_sub
 Function: Check if new registry is subset of baseline.  Note: equivalent is 
           considered subset.
 Args    : None
 Returns : true/false values

 Title   : is_super
 Usage   : $bool=$diff->is_super
 Function: Check if new registry is superset of baseline. Note: equivalent is 
           considered subset.
 Args    : None
 Returns : true/false values

 Title   : has_new
 Usage   : $bool=$registry->has_new
 Function: Check if new registry contains new collections
 Args    : None
 Returns : true/false values

 Title   : has_expanded
 Usage   : $bool=$registry->has_expanded
 Function: Check if new registry contains expanded collections
 Args    : None
 Returns : true/false values

=cut
