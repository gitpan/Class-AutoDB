package Class::AutoDB::SmartProxy;
use strict;
use Data::Dumper;
use Class::AutoDB::StoreCache;
use Class::AutoDB::DeleteCache;
use Class::AutoDB::TypeMap;
use Class::AutoClass;
use DBI;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS @EXPORT);
@ISA              = qw(Class::AutoClass);
@AUTO_ATTRIBUTES  = qw(dbh dsn dbd database host user password);
@OTHER_ATTRIBUTES = qw();
%SYNONYMS         = ( is_del => 'is_deleted' );
Class::AutoClass::declare(__PACKAGE__);

# global static references to caches
my $sc     = Class::AutoDB::StoreCache->instance();
my $dc     = Class::AutoDB::DeleteCache->instance();
my $tm     = new Class::AutoDB::TypeMap;
my $dumper =
	new Data::Dumper( [undef], ['thaw'] )->Purity(1)->Indent(1)->Freezer('DUMPER_freeze')
	->Toaster('DUMPER_thaw');

sub _init_self {
	my ( $self, $class, $args ) = @_;
	return if $self->{__object_id};        # already exists
	return if ref $self eq __PACKAGE__;    # don't proxy yourself
	$self->{_CLASS} = ref $self;
	$self->{__object_id} = _getUID();
	return $self;
}

sub DUMPER_freeze {
	my ($self) = @_;
	my $id        = $self->{__object_id} || _getUID();
	my $proxy_for = $self->{_CLASS} || ref $self;
	return bless { __object_id => $id, _CLASS => $proxy_for }, __PACKAGE__;
}
### in the future, DUMPER_thaw should handle object reconstitution - checking whether an instance exists in the
### cache or needs to be drawn from the data store. This is currently handled by the AUTOLOAD method (though
### caching is not well handled)
sub DUMPER_thaw {
	return $_[0];
}

# return a globally unique id string
# insert will require a unique ID. Done here (vs. DB autoincrementing) for portability.
sub _getUID {
	return
		int '1' . substr( rand( time . $$ ), 1, 14 );  # starting with a zero causes all sorta heartache
}

# this routine is strongly tied to the structure of SmartProxy's generated key
# if _getUID changes, so should this!
# future plans -> use a checksum to authenticate the key
sub is_valid_key {
	no warnings;    # stop complaints when checking unitialized values
	my ( $self, $key ) = @_;
	$key = $self unless $key;    # allow to be called as class method
	$key =~ /(^1[0-9]+)/;
	return length($1) > 0 ? 1 : 0;
}

# store() is only called by the user for explicit writes to the data store.
# The real work is passed to _persist() after the handler attribute has been set.
# calling store() on an object writes it immediatly to the data store. Auto persistence
# will not occur for an object that has been manually stored (this is to ensure the integrity
# of the object that you stored).
sub store {
	my $self = shift;
	$self->__handler('manual');    # keep track of object's storage method [auto|manual]
	_persist($self->__object_id);
}

sub _is_persistable {
	my $obj = shift;
		UNIVERSAL::isa( $obj, __PACKAGE__ )
		and not ref($obj) eq __PACKAGE__
		? 1
		: 0;
}

sub _persist {
	my $uid = shift;
	my ( $dbh );
	my $persistable = _unwrap($uid);
	return unless _is_persistable($persistable);
	my $registry = _unwrap($Class::AutoDB::Registry::REGISTRY_OID);
	# reconstuct dbh
	$dbh = Class::AutoDB::_connect($persistable) || $persistable->throw("cannot connect to database");
	my $oid = $persistable->{__object_id} || $persistable->throw("No object ID was associated with this object");
	my $collections = $sc->recall($persistable->{_CLASS});
	my $class = $persistable->{_CLASS};
	# insert collection names into object (makes it faster to delete)
	$persistable->{__collections} = $collections;
	foreach my $collection_name (@$collections) {
	  	my ( %collVals, %list );
		# filter out all but the searchable keys
		  my $collection = $registry->collection($collection_name);
		  return unless $collection;
			while ( my ( $k, $v ) = each %{ $collection->_keys } ) {
				next unless  $persistable->{$k};
				if ( $v =~ /list\(\w+\)/ ) { # handle lists
					next unless $persistable->{$k};
					$persistable->{$k} = $tm->clean( $v, $persistable->{$k} )
						unless $tm->is_valid( $v, $persistable->{$k} );
					foreach my $item ( @{ $persistable->{$k} } ) {
						# if items are scalar, just insert them. If they are SmartProxy objects, insert OIDs
						push @{ $list{ "$collection_name" . "_$k" } }, ref $item ? $item->{__object_id} : $item;
					}
					# insert list names into object (makes it faster to delete)
					$persistable->{__listname} = [ keys %list ];
				} elsif ( $v =~ /object/ ) { # object types will be stored with their oid as value
					unless ( $tm->is_valid( $v, $persistable->{$k} ) ) {
						$persistable->warn("non-AutoDB objects cannot be stored in this manner");
						$collVals{$k} = undef;
					} else {
						my $oid = $persistable->{$k}->{__object_id}
							|| $persistable->throw("stored object does not contain an object id (oid)");
						$collVals{$k} = $oid;
					}
				} else { # handle other keys - only simple scalars (strings) should reach here
					unless ( $tm->is_valid( $v, $persistable->{$k} ) ) {
						$persistable->warn("cannot store references and objects using type $v - value stored as undef");
						undef $persistable->{$k};
					} else {
						$collVals{$k} = $persistable->{$k};
					}
				}
			}
			my (@aggInsertCollKeys, $aggInsertCollKeys, @aggInsertableValues, $aggInsertableValues );
			# prepare searchable keys
			if ( values %$persistable ) {
				($aggInsertCollKeys) = join ",", 'oid', keys %collVals;
				while ( my ( $k, $v ) = each %{$collection->{_keys}} ) {
					next if $k =~ /^__/;    # filter system-specific keys
					push @aggInsertableValues, DBI::neat( $collVals{$k} ) if $collVals{$k};
					push @aggInsertCollKeys, $k if $collVals{$k};
				}
				unshift @aggInsertableValues, $oid;
				($aggInsertableValues) = join ",", @aggInsertableValues;    # format for insertion
				($aggInsertCollKeys) = join ",", 'oid', @aggInsertCollKeys;
			} else {                                                      # only the object_id is present
				$aggInsertCollKeys   = 'oid';
				$aggInsertableValues = $oid;
			}
			# handle collection associations (this object may be associated with multiple collections)
				my $c = $dbh->prepare(qq/insert into $Class::AutoDB::Registry::COLLECTION_TABLE values(?,?,?)/);
				$c->bind_param( 1, $oid );
				$c->bind_param( 2, $class );
				$c->bind_param( 3, $collection_name );
				$c->execute;
			# handle serialized object insertion
			my $freeze = $persistable->_wrap;
			my $so;
			$so = $dbh->prepare(qq/replace into $Class::AutoDB::Registry::OBJECT_TABLE(oid,object) values(?,?)/);
			$so->bind_param( 1, $persistable->{__object_id} );
			$so->bind_param( 2, $freeze );
			$so->execute;
			# handle top-level search keys
			$dbh->do(qq/replace into $collection_name($aggInsertCollKeys) values($aggInsertableValues)/);
			warn("$DBI::errstr") if $DBI::errstr;
			# handle list search keys
			foreach my $list_name ( keys %list ) {
				$dbh->do(qq/delete from $list_name where oid="$oid"/);
				foreach my $li ( @{ $list{$list_name} } ) {
					next unless $li;
					my $skl = $dbh->prepare(qq/insert into $list_name values(?,?)/);
					$skl->bind_param( 1, $oid );
					$skl->bind_param( 2, $li );
					$skl->execute;
				}
			}
	  }
  bless $persistable, 'NULL'; # mark for destruction
}

# given an object, will freeze the object and cache it
sub _wrap {
	my ( $self, $store ) = @_;
	$store ||= $self;
	return unless $tm->is_inside($store);
	my $oid = "$store->{__object_id}";
	# Make a shallow copy, replacing independent objects with:
	# stored reps if they are AutoDB able or
	# nothing if they are not (ignore non-AutoDB objs)
	my $persistable = { _CLASS => $store->{_CLASS} };
	while ( my ( $key, $value ) = each %$store ) {
		if ( $tm->is_inside($value) ) {
			$persistable->{$key} = $value->DUMPER_freeze;
		} elsif ( $tm->is_outside($value) ) {
			$persistable->{$key} = $value;
		} else {
			$persistable->{$key} = $value;
		}
	}

	# serialize whole object - excluding database handle (DBI complains)
	delete $persistable->{dbh};
	$dumper->Reset;
	my $freeze = $dumper->Values( [$persistable] )->Dump;
	$sc->cache( $oid, $freeze );
	return $freeze;
}

# given an oid, will retrieve the frozen object from the cache,
# defrost it and return it to the caller (returns false if object not cached)
sub _unwrap {
	my $oid     = shift;
	my $fetched = $sc->recall($oid);
	return 0 unless $fetched;
	my $thaw;
	eval $fetched;    # sets thaw
	my $name = $thaw->{_CLASS};
	return bless $thaw, $name;
}

sub AUTOLOAD {
	my ( $self, $value ) = @_;
	our $AUTOLOAD =~ /.*::(\w+)$/;
	return if $AUTOLOAD eq 'DESTROY';    # the books say you should do this
	my $oid = $self->{__object_id};
	$self->throw("requires oid (unique object identifier)") unless $oid;

	# set value - set never checks cache, only updates it.
	if ($value) {
		$self->{$1} = $value;

		#$sc->cache($self->{__object_id},$self);
		$self->_wrap;
	} else {                             # return value, no update
		if ( $self->{$1} ) {               # from cache
			return $self->{$1};
		} else {                           # have to go to data store
			my $sql = qq/SELECT * FROM $Class::AutoDB::Registry::OBJECT_TABLE WHERE oid='$oid'/;
			my $hash_ref = $sc->recall("Class::AutoDB")->{dbh}->selectall_hashref( $sql, 1 );
			$self->warn("Query: <$sql> produced no results") && return unless $hash_ref;
			my $frozen = $hash_ref->{$oid}->{'object'};
			my $thaw;
			no warnings;                     # otherwise the test harness gets unitialized warnings
			eval $frozen;                    # sets thaw
			#$sc->cache($self->{__object_id},$thaw);
			return $thaw->{$1} ? $thaw->{$1} : undef;
		}
	}
}

sub is_deleted {
	my ($self) = @_;
	my $oid    = $_[0]->{__object_id};
	my $flag   = 0;
	#$flag = $dc->recall($oid) ? 1 : 0;    # EZ case
	unless ($flag) {                      # gotta go dig for it
		my $dbh = $sc->recall("Class::AutoDB")->{dbh}
			|| $self->throw("cannot establish a database connection");
		my $sql = qq/SELECT count(*) FROM $Class::AutoDB::Registry::OBJECT_TABLE WHERE oid='$oid'/;
		my $count = $dbh->selectrow_array( $sql);
		$flag = $count ? 0 : 1;
		$dc->cache( $oid, $self );
	}
	return $flag;
}

sub DESTROY {
	my $obj = shift;
	return if $obj->{__handler} && $obj->{__handler} eq 'manual';
	_persist($obj->{__object_id}) if _is_persistable($obj);
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

# Title   : is_valid_key
# Usage   : $obj->is_valid_key($some_key);
# Function: checks if key _could have been_ created by _getUID
# Returns : 1 if true, 0 otherwise
# Args    : the key to check
# Notes   :

# Title   : store
# Usage   : $obj->store;
# Function: immediately writes object to the database
# Returns : the frozen object (a string)
# Args    : 
# Notes   : Automatic persistence will not occur for an object that has been manually stored 
#           (this is to ensure the integrity of the object that you stored)

=cut
