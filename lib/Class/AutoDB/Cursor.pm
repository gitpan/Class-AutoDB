package Class::AutoDB::Cursor;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Registry;
use Data::Dumper;
@ISA              = qw(Class::AutoClass);      # AutoClass must be first!!
@AUTO_ATTRIBUTES  = qw(args _count objects);
@OTHER_ATTRIBUTES = qw();
%SYNONYMS         = ();
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
	my ( $self, $class, $args ) = @_;
	return unless $class eq __PACKAGE__;         # to prevent subclasses from re-running this
	$self->args($args);
	$self->_reconstitute($args);
	return $self;
}

# reconstitute the object with its stored data -
# $data param contains a collection object and, optionally, search keys
sub _reconstitute {
	my ( $self, $data ) = @_;
	my @objects;
	# if collection(s) were given, they will be iterated over - else ALL collections will be
	my $collections = $data->search->collection;
	my $classes     = $data->search->class;
	$self->throw(
					 "Class::AutoDB::Cursor requires a Class::AutoDB::Collection object and your search keys")
		unless $collections;
	my (
		%searchable_keys,           # user-specified keys to search
		%searchable_collections,    # user-specified collections to search
		%searchable_classes,        # user-specified classes to search
		%collection,								# collection objects for searched collections
		$sql,                       #  SQL query string
		%oids,                      # unique oid's
		$ary_ref
		 );

	# get a unique list of all search params
	map { $searchable_classes{$_}++ } @$classes;
	map { $searchable_collections{$_}++ } @$collections;

	# filter for existing keys (ignore class and collection args)
	foreach ( keys %{ $data->search } ) {
		next if $_ eq 'collection';
		next if $_ eq 'class';
		next if $_ =~ /__search/;    # search flags
		$searchable_keys{$_} = $data->search->{$_};
	}
	$sql = qq/SELECT DISTINCT * FROM 
  		                $Class::AutoDB::Registry::COLLECTION_TABLE WHERE/;
	if ( my $arg_cnt = ( scalar keys %searchable_collections ) ) {
		foreach ( keys %searchable_collections ) {
			$arg_cnt--;
			$sql .= qq/ collection_name="$_" /;
			$sql .= " OR " if $arg_cnt;
		}
	}
	if ( my $arg_cnt = ( scalar keys %searchable_classes ) ) {    # class search
		$sql .= ' AND (' if $sql =~ /collection_name/;
		foreach ( keys %searchable_classes ) {
			$arg_cnt--;
			$sql .= qq/ class_name="$_" /;
			$sql .= " OR " if $arg_cnt;
		}
		$sql .= ')' if $sql =~ /collection_name/;
	}
	# now query for attributes (other than class,collection), if any
	if ( scalar keys %searchable_keys ) {
		my $valid_rows = $data->{dbh}->selectall_hashref( $sql, 2 );    # key on collection_name
		my ($registry) = $data->{dbh}->selectrow_array(
		   qq(SELECT object FROM 
		   $Class::AutoDB::Registry::OBJECT_TABLE WHERE 
		   oid="$Class::AutoDB::Registry::REGISTRY_OID"));
    my $thaw;
    eval $registry;    # sets $thaw
		foreach my $coll (keys %$valid_rows) {
		   while(my($k,$v) = each %{$thaw->{name2coll}->{$coll}->{_keys}}) {
		     if($v =~ /list/) {
		       $collection{$coll .  '_' . $k}++; # add list name to %collection
		     } else {
		       $collection{$coll}++;
		     }
		   }
		}
		foreach my $rowref ( keys %collection ) {
			my $sql = qq/SELECT DISTINCT oid FROM 
  		                 $rowref WHERE /;
			my $arg_cnt = scalar keys %searchable_keys;
			while ( my ( $k, $v ) = each %searchable_keys ) {
				$sql .= " $k = \'$v\' ";
				$sql .= " AND " if --$arg_cnt;
			} 				
				$ary_ref = $data->{dbh}->selectall_arrayref($sql);
				last if $ary_ref;
		}
	} else { # no searchable attributes
		$ary_ref = $data->{dbh}->selectall_arrayref($sql);
	}
	# reconstitution - create an instance of the stored object
	foreach (@$ary_ref) {
		my $oid = $_->[0];
		next if $oids{$oid};
		$oids{ $_->[0] }++;
		my ( $fetched, $thaw );
		$sql = qq/select object from $Class::AutoDB::Registry::OBJECT_TABLE where oid=$oid/;
		eval { $fetched = $data->{dbh}->selectall_arrayref($sql) };
		next unless $fetched->[0];
		eval $fetched->[0]->[0];    # sets thaw
		push @objects, bless $thaw, $thaw->{_CLASS};
	}
	$self->_count( scalar @objects );
	$self->objects( \@objects );
}

# return the number of objects in the retrieved collection
sub count {
	my $self = shift;
	$self->reset;
	defined $self->_count || $self->_count( scalar @{ $self->{objects} } ) || $self->_count(0);
	return defined $self->_count ? $self->_count : 0;
}

# grab all the elements of the retrieved collection
sub get {
	my $self = shift;
	return @{ $self->objects };
}

# get_next: iterator over collections
sub get_next {
	my $self = shift;
	my $next = sub { return ( $self->_count( $self->_count - 1 ) - 1 ) };
	my $this = $next->();
	if ( $self->_count < 0 ) {
		$self->_count(0);
		return undef;
	} else {
		return $self->objects->[$this];
	}
}

# reset Cursor's object count
# called explicitly to reset the iterator
sub reset {
	 my $self = shift;
	 $self->_count(undef);
	 $self->_reconstitute($self->args);
}

# applies the passed subroutine reference to stored objects
sub traverse {
	my $self = shift;
	$self->throw("not implemented");
}
1;
__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::Cursor

=head1 SYNOPSIS

use Class::AutoDB::Cursor;

$cursor = Class::AutoDB->new(
                            -dsn=>"DBI:$DB_NAME:database=$DB_DATABASE;host=$DB_SERVER",
                            -user=>$DB_USER,
                            -password=>$DB_PASS,
                            -find=>{-collection=>'TestAutoDB'}
                          );

-- or --

$autodb = Class::AutoDB->new(
                            -dsn=>"DBI:$DB_NAME:database=$DB_DATABASE;host=$DB_SERVER",
                            -user=>$DB_USER,
                            -password=>$DB_PASS
                          );


$cursor = $autodb->find(-collection=>'TestAutoDB');

=head1 DESCRIPTION

Cursor object is a wrapper around persistant objects. It will return all objects or
iterate (NOT YET IMPLEMENTED) over objects that the user has requested to fetch (usually through Class::AutoDB::find method).

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

 Usage   : $cursor=new Class::AutoDB::Cursor($args);
 Function: Create object
 Returns : New Class::AutoDB::Cursor object
 Args    : Class::AutoClass::Args instance containing the following arguments:
           -search
           -DBI::dbh
           -collection
 Notes   : see CursorTest.t for working examples
           
=head2 get
 Usage   : $cursor->get;
 Function: Retrieves persisted collections
 Returns : an arrayref of objects
 Args    : None
 Notes   : see CursorTest.t for working examples
 
=head2 get_next
 Usage   : $cursor->get_next;
 Function: iterator over recalled collections
 Returns : an object, undef if last object
 Args    : None
 Notes   : $cursor->reset to reset iterator pointer. See CursorTest.t for working examples
 
 =head2 reset
 Usage   : $cursor->reset;
 Function: reset iterator to point to first object in retrieved collection
 Returns : 
 Args    : None
 Notes   : See CursorTest.t for working examples
=cut
