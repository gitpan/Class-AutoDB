package Class::AutoDB::Cursor;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Data::Dumper;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

BEGIN {
  @AUTO_ATTRIBUTES=qw();
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);
}

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this 
  $self->{objects} = [];
  $self->_slot($args);
  return $self;
}

# reconstitute the blessed hash with its stored data
sub _slot {
  my($self,$data) = @_;
  unless($data->{search} && $data->{collection}) {
    $self->throw("Class::AutoDB::Cursor requires a Class::AutoDB::Collection object and your search keys");
  }
  my (%searchable,$sql,$search_all, $no_match);
  my $collection_name = $data->collection->name;
  # %searchable holds which keys to query the database against - all keys if only the collection specified
  if((scalar keys %{$data->search} == 1) && (exists $data->search->{collection})) {
    $search_all = 1;
  } else {
    foreach(keys %{$data->search}) {
  	  next if $_ eq 'collection';
  	  unless($data->collection->_keys->{$_}) {
  	    warn("can't find key named \'$_\' in $collection_name, ignoring it");
  	    next;
  	  }
  	  $searchable{$_} = $data->search->{$_};
    }
  }

    $sql = "SELECT * FROM $collection_name";
    my $arg_cnt = (scalar keys %searchable);
    
    # AND together the query attributes
    unless($search_all) {
      $sql .= " WHERE ";
      while(my($k,$v) = each %searchable) {
        $arg_cnt--;
        $sql .= " $k = \'$v\' ";
        $sql .= " AND " if $arg_cnt;
      }
    }
    
    my $ary_ref = $data->{dbh}->selectall_arrayref($sql);
	
    # reconstitution
    foreach(@$ary_ref){
      #populate attribute through autoargs method
      my $cnt = 1;
      # re-bless as class of package collection_name
      my $obj = _rebless($collection_name);
      while(my($k,$v) = each %{$data->collection->_keys}) {
      	# user just asked for the collection - give them everything
      	if($search_all){
      	  # handle lists
      	  if($v =~ m|list\(\w+\)|){ 
      	  	my $list_ref = $data->{dbh}->selectrow_hashref(_fetch_statement($collection_name, $_->[0], $k));
      	  	my $thaw;			# variable used in frozen list
      	  	eval $list_ref->{$k};		# sets $thaw
      	  	$obj->$k($thaw) || next;
      	  } else {
             $obj->$k($_->[$cnt++]);
      	  }
      	# otherwise user wants only the requested keys - user gets undef iff all search keys not found
      	} else {
      	    # handle lists
      	    if($v =~ m|list\(\w+\)| && $searchable{$k}){
      	  	  my $list_ref = $data->{dbh}->selectrow_hashref(_fetch_statement($collection_name, $_->[0], $k ));
      	  	  my $thaw;			# variable used in frozen list
              eval $list_ref->{$k};		# sets $thaw
      	  	  $obj->$k($thaw);
      	    } else {
                $obj->$k($searchable{$k}) if $searchable{$k};
      	    }
      	}
      	  # record the object's id so we can update it
          $obj->{__object_id}=$_->[0];
          # this is not a new object
          delete $obj->{UID};
      }
      # this is a proxy of the object, so we say so
      $obj->{__proxyobj}=1;
      push @{$self->{objects}}, $obj;
    }
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

#bless a {} and return it
sub _rebless {
  my $collection = shift;
  return bless {}, $collection;
}

sub get {
  my $self = shift;
  return @{$self->{objects}};
}

# iterates over stored objects
sub get_next {
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
           

=head2 _fetch_Statement
 Usage   : Class::AutoDB::Cursor::_fetch_statement("CollectionName", "ID", "ListName");
 Function: generates sql SELECT statement for scalar, list selects
 Returns : String
 Args    : Collection name, a unique identifier, [list name]
 Notes   : see CursorTest.t for working examples
 
=head2 _rebless
 Usage   : Class::AutoDB::Cursor::_rebless("saint");
 Function: blesses an ananymous hash into passed argument
 Returns : Object
 Args    : String, name of class to be blessed into
 Notes   : see CursorTest.t for working examples

=head2 _slot
 Usage   : $cursor->_slot($args);
 Function: Reconstitute the blessed hash with its stored data
 Returns : an arrayref of proxied objects (objects that have been reblessed as new and marked)
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
