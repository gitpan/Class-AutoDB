package Class::AutoDB::SmartProxy;

use strict;
use Data::Dumper;
use Class::AutoDB::WeakCache;
use Class::AutoClass;
use vars qw(@ISA);
@ISA=qw(Class::AutoClass);

# global static reference to weak cache
my $wc = Class::AutoDB::WeakCache->instance();

sub _init_self {
  my($self,$class,$args)=@_;
  $self->{__proxy_for}=$args->collection_name || $class; # don't forget your roots
  return if $self->{__proxy_for} eq __PACKAGE__; # don't proxy yourself
  if($args->__object_id) {
    $self->{__object_id}=$args->{__object_id};
    $self->{__listname}=$args->{__listname};
  } else {
  	$self->{__object_id}=_getUID();
  	$self->{__state}='new';
  }
  bless $self, __PACKAGE__;
  # remember the relationship
  $wc->cache($self->{__object_id},$self);
  freeze($self,$self->{__object_id});
  return $self;
}

sub freeze{
  my ($self)=shift;
  ## TODO: move the AutoDB persistence code here??
  $wc->recall("Class::AutoDB")->store($self->{__object_id});
}

# return a globally unique id string
# insert will require a unique ID. Done here (vs. DB autoincrementing) for portability.
sub _getUID {
  return '1'.substr($$.(time % rand(time)),1,9); # starting with a zero causes all sorta heartache
}

sub AUTOLOAD {
  my ($self,$value)=@_;
  our $AUTOLOAD =~ /.*::(\w+)$/;
  $self->throw("No object ID is associated with the object you are trying to freeze") unless $self->{__object_id};
  # set value
  if ($value) {
    my $cached_self = $wc->recall($self->{__object_id});
    $cached_self->{$1}=$value;
    $cached_self->{__state}='update';
    $wc->cache($self->{__object_id},$cached_self);
    freeze($cached_self);
    return $cached_self->{$1};
  } else { # return value, no update
      my $cached_self = $wc->recall($self->{__object_id});
      if ($cached_self->{$1}) {
        return $cached_self->{$1};
      } else { # have to go to data store
          my $sql = qq/SELECT * FROM $Class::AutoDB::Registry::OBJECT_TABLE WHERE id='$self->{__object_id}'/;
          my $hash_ref = $wc->recall("Class::AutoDB")->{dbh}->selectall_hashref($sql,1);
          ($self->warn("Query: <$sql> produced no results") && return) unless $hash_ref;
          my $frozen = $hash_ref->{$self->{__object_id}}->{'object'};
          my $thaw;
          eval $frozen; # sets thaw
          $thaw->{__state}='update';
          $wc->cache($self->{__object_id},$thaw);
          return $thaw->{$1};
    }
  }
}


1;

__END__


=head1 NAME

Class::AutoDB::SmartProxy

=head1 SYNOPSIS

use Class::AutoDB::SmartProxy;

=head1 DESCRIPTION


=head1 KNOWN BUGS AND CAVEATS

This is still a work in progress.  

=head2 Bugs, Caveats, and ToDos

  TBD

=head1 AUTHOR - Nat Goodman, Chris Cavnor

Email ccavnor@systemsbiology.org

=head1 COPYRIGHT

Copyright (c) 2003 Institute for Systems Biology (ISB). All Rights Reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 APPENDIX

The rest of the documentation describes the methods.

=head2 Constructor

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : 
 Notes   : 



=cut
