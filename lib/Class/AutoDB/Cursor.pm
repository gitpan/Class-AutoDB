package Class::AutoDB::Cursor;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Data::Dumper; ## only of debugging
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

  @AUTO_ATTRIBUTES=qw(args);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $self->args($args);
  $self->_create_flyweight($args);
  return $self;
}

# reconstitute the blessed hash with its stored data -
# $data param contains a collection object and, optionally, search keys
sub _create_flyweight {
  my($self,$data) = @_;
  my @objects;
  unless($data->{collection}) {
    $self->throw("Class::AutoDB::Cursor requires a Class::AutoDB::Collection object and your search keys");
  }
  my (@searchkeys,%searchable,$sql);
  my $collection_name = $data->collection->name;
  my $listname;
  while (my($k,$v)=each %{$data->collection->_keys}) {
    if ( $v =~ /^list/ ) { $listname=$k; last }
  }
  ###
  ### get all the records that satisfy the query params for the collection
  ###
  if(exists $data->{search} && exists $data->search->{collection}) {
    @searchkeys = keys %{$data->search};
  }
  foreach (@searchkeys) {
	    next if $_ eq 'collection';
	    unless($data->collection->_keys->{$_}) {
	      $self->warn("can't find key named \'$_\' in $collection_name, ignoring it");
	      next;
	    }
	    $searchable{$_} = $data->search->{$_};
  }
  $sql = "SELECT * FROM $collection_name";
  my $arg_cnt = (scalar keys %searchable);
  
  # AND together the query attributes
  if(scalar keys %searchable) {
    $sql .= " WHERE ";
    while(my($k,$v) = each %searchable) {
      $arg_cnt--;
      $sql .= " $k = \'$v\' ";
      $sql .= " AND " if $arg_cnt;
    }
  }
  my $ary_ref;
  eval{ $ary_ref = $data->{dbh}->selectall_arrayref($sql) };
  $self->warn("Query: <$sql> produced no results") unless $ary_ref;
  ###
  ### reconstitution - record the object's id and origination class so we can update it
  ### 
	foreach(@$ary_ref){
    my $obj = Class::AutoDB::SmartProxy->new(collection_name=>$collection_name, __object_id=>$_->[0], __listname=>$listname);
    push @objects, $obj;
  }
  $self->{__count} = scalar @$ary_ref;
  $self->{objects} =  \@objects;
}

# prepare SQL statement for fetching. If list argument is passed, statement
# for fetching the list is generated
sub _fetch_statement {
  my($collection_name,$id,$list) = @_;
  my $table_name;
  if($list) {
   $table_name = $collection_name . "_" . $list;
  }else {
  	$table_name = $collection_name;
  }
  return "SELECT * FROM $table_name WHERE object = $id";	
}
# return the number of objects in the retrieved collection
sub count {
  my $self=shift;
  $self->reset;
  return defined $self->{objects} ? scalar @{$self->{objects}} : 0;
}

# grab all the elements of the retrieved collection
sub get {
  my $self = shift;
  return @{$self->{objects}};
}

# get_next: iterator for returned collections
sub get_next {
  my $self=shift;
  my $next=sub{ return --$self->{__count} };
  my $this=$next->();
  if( $this == -1 ) { 
    $self->{__count}=0;
    return undef;
  } else {
    return $self->{objects}->[$this];
  }
}

# reset Cursor's object count
# called explicitly to reset the iterator
sub reset {
  my $self=shift;
  my $cur_count=$self->{__count}; # remember iterator position
  $self->_create_flyweight($self->args);
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
 Returns : an arrayref of proxied objects (objects that have been reblessed as new and marked)
 Args    : None
 Notes   : see CursorTest.t for working examples
 
=head2 get_next (NOT YET IMPLEMENTED)
 Usage   :
 Function:
 Returns : 
 Args    : 
 Notes   : (see CursorTest.t for working examples)
=cut
