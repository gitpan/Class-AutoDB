package Class::AutoDB::SmartProxy;

use strict;
use Data::Dumper;
use Class::AutoDB::StoreCache;
use Class::AutoDB::DeleteCache;
use Class::AutoClass;
use DBI;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS @EXPORT);
@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw();
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=( is_del => 'is_deleted' );
Class::AutoClass::declare(__PACKAGE__);

# global static references to caches
my $sc = Class::AutoDB::StoreCache->instance();
my $dc = Class::AutoDB::DeleteCache->instance();

my $tm = new Class::AutoDB::TypeMap;
my $dumper = new Data::Dumper([undef],['thaw'])->Purity(1)->Indent(1)->
  Freezer('DUMPER_freeze')->Toaster('DUMPER_thaw');
  
my %state; # keep track of object state [undef|NULL]
my %handler; # keep track of object's storage method [auto|manual]
my $destroyed = 0; # global flag to track when destruction begins
  
sub _init_self {
  my($self,$class,$args)=@_;
  return if $self->{__object_id}; # already exists
  return if ref $self eq __PACKAGE__; # don't proxy yourself
  $self->{__proxy_for}=$args->collection_name || ref $self; # don't forget your roots
  $self->{__object_id}=_getUID();
  return $self;
}

sub DUMPER_freeze {
  my($self)=@_;
  my $id = $self->{__object_id} || _getUID();
  my $proxy_for = $self->{__proxy_for} || ref $self;
  return bless { __object_id=>$id,__proxy_for=>$proxy_for }, __PACKAGE__;
}

### in the future, thaw should handle object reconstitution - checking whether an instance exists in the
### cache or needs to be drawn from the data store. This is currently handled by the AUTOLOAD method (though 
### caching is not well handled)
sub DUMPER_thaw {
 return $_[0];
}

# return a globally unique id string
# insert will require a unique ID. Done here (vs. DB autoincrementing) for portability.
sub _getUID {
  return '1'.substr($$.(time % rand(time)),1,9); # starting with a zero causes all sorta heartache
}

# store() is only called by the user for explicit writes to the data store.
# The real work is passed to _persist() after the handler attribute has been set.
# calling store() on an object writes it immediatly to the data store. Auto persistence
# will not occur for an object that has been manually stored (this is to ensure the integrity
# of the object that you stored).
sub store {
  my $self = shift;
  $handler{$self->{__object_id}} = 'manual';
  $self->_persist;
}

sub _persist {
  my ($self,$freeze)=@_;
  # return unless we can access AutoDB members - this happens during global cleanup
  my $adb = $sc->recall("Class::AutoDB") or return;
  my $registry = $adb->{registry} or return;
  my $dbh = $adb->{dbh} or return;
  my $persistable_name = $self->{__proxy_for} || $self->throw("Not sure who object is proxying");
  my $oid = $self->{__object_id} || $self->throw("No object ID was associated with this object");
  my (%collVals, %list, $list_name);
  return if ( $destroyed and $handler{$oid} and $handler{$oid} eq 'manual' );
  
  # need the frozen object somehow
  unless ( $freeze ) {
     unless ( $freeze = $sc->recall($oid) ) {
        $freeze = $self->_wrap;
     }
  }

  my $persistable = $self->_unwrap($oid);  
  my @insertable=();
  
  # filter out all but the searchable keys
  foreach my $collection ($registry->collections) {
    next unless $collection->name eq $persistable_name;
	  	while(my($k,$v) = each %{$collection->_keys}) {
	  	  next unless exists $persistable->{$k};
		    # handle lists
		    if($v =~ /list\(\w+\)/) {
		      next unless $self->{$k};
		      $persistable->{$k} = $tm->clean($v, $persistable->{$k})
		        unless $tm->is_valid($v, $persistable->{$k});
			    foreach my $item (@{$persistable->{$k}}) {
		        # if items are scalar, just insert them. If they are SmartProxy objects, insert OIDs
            push @insertable, ref $item ? $item->{__object_id} : $item;
		      }
		      $list_name = "$persistable_name"."_$k";
		      # insert list name into object (delete requires it)
		      $self->{__listname} = $list_name;
		      $list{$list_name} = \@insertable;
		      # delete from top-level search keys (handled)
		      delete $persistable->{$k};
		   # object types will be stored with their oid as value
		   } elsif ($v =~ /object/) {
		       unless($tm->is_valid($v, $persistable->{$k})) {
		        $self->warn("non-AutoDB objects cannot be stored in this manner");
		        $collVals{$k} = undef;
		       } else {
		         my $oid = $persistable->{$k}->{__object_id} ||
		           $self->throw("stored object does not contain an object id (oid)");
		        $collVals{$k} = $oid;
		       }
		   }  else {
	       # handle other keys - only simple scalars (strings) should reach here
	       unless($tm->is_valid($v, $persistable->{$k})) {
	         $self->warn("cannot store references and objects using type $v - value stored as undef");
	         undef $persistable->{$k};
	       } else {
	         $collVals{$k} = $persistable->{$k};
	       }
		   }
	   }
  }
     
  my ($aggInsertCollKeys,@aggInsertableValues,$aggInsertableValues);
  # prepare searchable keys
	if (values %$persistable) {
	  ($aggInsertCollKeys) = join ",",'object', keys %collVals;
	  while(my($k,$v) = each %$persistable) {
	  	next if $k =~ /^__/; # filter system nvp's
	    push @aggInsertableValues, DBI::neat($collVals{$k}) if $collVals{$k};
	  }
	  unshift @aggInsertableValues, $oid;
	  ($aggInsertableValues) = join ",", @aggInsertableValues; # format for insertion
	} else { # only the object_id is present
	   $aggInsertCollKeys = 'object';
	   $aggInsertableValues = $oid;
	}
  
  # handle serialized object insertion
  my $so;
  $so = $dbh->prepare(qq/replace into $Class::AutoDB::Registry::OBJECT_TABLE values(?,?)/);
	$so->bind_param(1,$persistable->{__object_id});
	$so->bind_param(2,$freeze);
	$so->execute;
	$self->throw("object serialization failed") if $@;

  ### handle top-level search keys
  $dbh->do(qq/replace into $persistable_name($aggInsertCollKeys) values($aggInsertableValues)/);
  # handle list search keys
  if( scalar keys %list ) {
    # serialize list
    $dumper->Reset;
    my $freeze=$dumper->Values([\@insertable])->Dump;
    my $skl = $dbh->prepare(qq/replace into $list_name values(?,?)/);
	  $skl->bind_param(1,$oid);
	  $skl->bind_param(2,$freeze);
    $skl->execute;
  }
}

# given an object, will freeze the object and cache it
sub _wrap {
  my($self,$store)=@_;
  $store ||= $self;
  return unless $tm->is_inside($store);
  my $oid = "$store->{__object_id}";
  
  # Make a shallow copy, replacing independent objects with:
  # stored reps if they are AutoDB able or
  # nothing if they are not (ignore non-AutoDB objs)
  my $persistable={__proxy_for=>$store->{__proxy_for}};
  while(my($key,$value)=each %$store) {
    if ($tm->is_inside($value)) {
      $persistable->{$key}=$value->DUMPER_freeze;
     } elsif ($tm->is_outside($value)) {
       $persistable->{$key}=$value;
     } else {
        $persistable->{$key}=$value;
     }
  }
  # serialize whole object
  $dumper->Reset;
  my $freeze=$dumper->Values([$persistable])->Dump;
  $sc->cache( $oid, $freeze );
  return $freeze;
}

# given an oid, will retrieve the frozen object from the cache, 
# defrost it and return it to the caller (returns false if object not cached)
# this instance is marked as NULL so that it won't be persisted
sub _unwrap {
  my($self,$oid)=@_;
  my $fetched = $sc->recall($oid);
  return 0 unless $fetched;
  my $thaw;
  eval $fetched; # sets thaw
  $thaw->{__state} = 'NULL'; # inhibits persistence
  return bless $thaw, $thaw->{__proxy_for};
}

sub AUTOLOAD {
  my ($self,$value)=@_;
  my $class = ref $self;
  our $AUTOLOAD =~ /.*::(\w+)$/;
  my $oid = $self->{__object_id};
  $self->throw("requires oid (unique object identifier)") unless $oid;
  
  # set value - set never checks cache, only updates it.
  if ($value) {
   $self->{$1}=$value;
   #$sc->cache($self->{__object_id},$self);
   $self->_wrap;
  }
  else { # return value, no update
      if ($self->{$1}) { # from cache
        return $self->{$1};
      } else { # have to go to data store
          my $sql = qq/SELECT * FROM $Class::AutoDB::Registry::OBJECT_TABLE WHERE id='$oid'/;
          my $hash_ref = $sc->recall("Class::AutoDB")->{dbh}->selectall_hashref($sql,1);
          $self->warn("Query: <$sql> produced no results") && return unless $hash_ref;
          my $frozen = $hash_ref->{$oid}->{'object'};
          my $thaw;
          no warnings; # otherwise the test harness gets unitialized warnings
          eval $frozen; # sets thaw
          #$sc->cache($self->{__object_id},$thaw);
          return $thaw->{$1} ? $thaw->{$1} : undef;
    }
  }
}

sub is_deleted {
  my ($self)=@_;
  my $oid = $_[0]->{__object_id};
  my $flag = 0;
  $flag = $dc->recall($oid) ? 1 : 0; # EZ case
  unless($flag) { # gotta go dig for it
    my $dbh = $sc->recall("Class::AutoDB")->{dbh} 
      || return $flag=0;
    my $sql = qq/SELECT object FROM $Class::AutoDB::Registry::OBJECT_TABLE WHERE id='$oid'/;
    my $hash_ref = $dbh->selectall_hashref($sql,1);
    $self->warn("Query: <$sql> produced no results") && return unless $hash_ref;
    $flag=1 if $hash_ref->{$oid}->{'object'};
    $dc->cache($oid,$self);
  }
  return $flag;
}

sub DESTROY {
 my ($self) = @_;
 return if ref $self eq __PACKAGE__; # skip top-level SP objects (but not derived classes)
 if ($self->can("store")) {
   return if ($self->{__state} and $self->{__state} eq 'NULL'); # ignore objs with state=NULL, they are cache copies
   $destroyed = 1; # signal that glabal destruction has begun
   $self->_persist;
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

# Title   : new
# Usage   : $sp = Class::AutoDB::SmartProxy->new
# Function: creates a lightweight proxy for AutoDB use
# Returns : Class::AutoDB::SmartProxy object
# Args    : collection_name
# Notes   : not normally directly instantiated - used for inheritance

# Title   : AUTOLOAD
# Usage   : normally called via perl method dispatch
# Function: handles method calls for AutoDB objects
# Returns : acts as a getter for the method call if no value passed
# Args    : acts as a setter for the method call if value passed
# Notes   : 

# Title   : DUMPER_freeze
# Usage   : only called by Data::Dumper
# Function: creates proxy for object being frozen 
# Returns : 
# Args    : 
# Notes   : 

# Title   : DUMPER_thaw
# Usage   : only called by Data::Dumper
# Function: currently does nothing
# Returns : 
# Args    : 
# Notes   : 

# Title   : is_deleted
# Usage   : $obj->is_deleted;
# Function: checks if object has been deleted from database
# Returns : 1 if deleted, 0 otherwise
# Args    : none
# Notes   : checks cache for objects deleted in current session, otherwise checks database

# Title   : store
# Usage   : $obj->store;
# Function: immediately writes object to the database
# Returns : the frozen object (a string)
# Args    : 
# Notes   : Automatic persistence will not occur for an object that has been manually stored 
#           (this is to ensure the integrity of the object that you stored)

=cut
