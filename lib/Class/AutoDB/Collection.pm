package Class::AutoDB::Collection;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Table;
use Class::AutoDB::BaseTable;
use Class::AutoDB::ListTable;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

BEGIN {
  @AUTO_ATTRIBUTES=qw(name
		      _keys _tables _cmp_data);
  @OTHER_ATTRIBUTES=qw(register);
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);
}
sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}
sub register {
  my $self=shift;
  my @registrations=_flatten(@_);
  my $keys=$self->keys or $self->keys({});
  for my $reg (@registrations) {
    my $reg_keys=$reg->keys;
    while(my($key,$type)=each %$reg_keys) {
      $type=lc $type;
      $keys->{$key}=$type, next unless defined $keys->{$key};
      $self->throw("Inconsistent registrations for search key $key: types are ".$keys->{$key}." and $type") unless $keys->{$key} eq $type;
    }
  }
  $self->_keys($keys);
  $self->_tables(undef);	# clear computed value so it'll be recomputed next time 
}
sub keys {
  my $self=shift;
  my $result= @_? $self->_keys($_[0]): $self->_keys;
  $result or $result={};
  wantarray? %$result: $result;
}
sub merge {
  my($self,$diff)=@_;
  my $keys=$self->keys || {};
  my $new_keys=$diff->new_keys;
  @$keys{keys %$new_keys}=values %$new_keys;
  $self->keys($keys);
  $self->_tables(undef);	# clear computed value so it'll be recomputed next time 
}
sub put {
  my($self,$object)=@_;
  # instantiate values of search keys
  my %key_values;
  my %keys=$self->keys;
  while(my($key,$type)=each %keys) {
    my $method=UNIVERSAL::can($object,$key);
    next unless $method;
    my $value=$object->$method;
    if ($type eq 'object' && defined $value) {
      $value=$value->oid;
    } elsif ($type eq 'list(object)' && defined $value) {
      @$value=map {$_->oid} @$value
    }
    $key_values{$key}=$value;
  }
  # generate SQL to store object in each table
  my $oid=$object->oid;
  my @sql=map {$_->put($oid,\%key_values)} $self->tables;
  wantarray? @sql: \@sql;
}
sub create {
  my($self)=@_;
  my @sql=map {$_->drop} $self->tables;	# drop tables if they exist
  push(@sql,map {$_->create} $self->tables);
  wantarray? @sql: \@sql;
}
sub drop {
  my($self)=@_;
  my @sql=map {$_->drop} $self->tables;
  wantarray? @sql: \@sql;
}
 
sub alter {
  my($self,$diff)=@_;
  my @sql;
  my $new_keys=$diff->new_keys;
  my $name=$self->name;
  # Split new keys to be added into scalar vs. list
  my($scalar_keys,$list_keys);
  while(my($key,$type)=each %$new_keys) {
    _is_list_type($type)? $list_keys->{$key}=$type: $scalar_keys->{$key}=$type;
  }
  # New scalar keys have to be added to base table
  # Create a Table object to hold these new keys.
  # Just for programming convenience -- this is not a real table
  my $base_table=new Class::AutoDB::BaseTable (-name=>$name,-keys=>$scalar_keys);
  push(@sql,$base_table->schema('alter'));
  # New list keys have to generate new tables
  while(my($key,$type)=each %$list_keys) {
    my($inner_type)=$type=~/^list\s*\(\s*(.*?)\s*\)/;
    my $list_table=new Class::AutoDB::ListTable (-name=>$name.'_'.$key,
						-keys=>{$key=>$inner_type});
    push(@sql,$list_table->drop);   # drop table if exists
    push(@sql,$list_table->create); # create table
  }
  $self->_tables(undef);	# clear computed value so it'll be recomputed next time 
  wantarray? @sql: \@sql;
}
sub tables {
  my $self=shift;
  return $self->_tables(@_) if @_;
  unless (defined $self->_tables) {
    my $name=$self->name;
    # Collection has one 'base' table for scalar keys and one 'list' table per list key
    #
    # Start by splitting keys into scalar vs. list
    my $keys=$self->keys;
    my($scalar_keys,$list_keys)=({},{});
    while(my($key,$type)=each %$keys) {
      _is_list_type($type)? $list_keys->{$key}=$type: $scalar_keys->{$key}=$type;
    }
    my $base_table=new Class::AutoDB::BaseTable(-name=>$name,-keys=>$scalar_keys);
    my $tables=[$base_table];
    while(my($key,$type)=each %$list_keys) {
      my($inner_type)=$type=~/^list\s*\(\s*(.*?)\s*\)/;
      my $list_table=new Class::AutoDB::ListTable (-name=>$name.'_'.$key,
						  -keys=>{$key=>$inner_type});
      push(@$tables,$list_table);
    }
    $self->_tables($tables);
  }
  wantarray? @{$self->_tables}: $self->_tables;
}
sub tidy {
  my $self=shift;
  $self->_tables(undef);
}

sub _is_list_type {$_[0]=~/^list\s*\(/;}
sub _flatten {map {'ARRAY' eq ref $_? @$_: $_} @_;}
  
1;

__END__

=head1 NAME

Class::AutoDB::Collection - Schema information for one collection

=head1 SYNOPSIS

This is a helper class for Class::AutoDB::Registry which represents the
schema information for one collection.

 use Class::AutoDB::Registration;
 use Class::AutoDB::Collection;
 my $registration=new Class::AutoDB::Registration
   (-class=>'Person',
    -collection=>'Person',
    -keys=>qq(name string, dob integer, significant_other object, 
              friends list(object)),
    -transients=>[qw(age)],
    -auto_gets=>[qw(significant_other)]);
 
 my $collection=new Class::AutoDB::Collection
   (-name=>'Person',-register=>$registration);
 
 # Get the object's attributes
 my $name=$collection->name; 
 my $keys=$collection->keys;            # hash of key=>type pairs
 my $tables=$collection->tables;        # Class::AutoDB::Table objects 
                                        #   that implement this collection 
 
 my @sql=$collection->schema;           # SQL statements to create collection
 my @sql=$collection->schema('create'); # same as above
 my @sql=$collection->schema('drop');   # SQL statements to drop collection
 my @sql=$collection->schema('alter',$diff); 
                                        # SQL statements to alter collection
                                        #   ($diff is CollectionDiff object)

=head1 DESCRIPTION

This class represents processed registration information for one
collection. Registrations are fed into the class via the 'register'
method which combines the information to obtain a single hash of
key=E<gt>type pairs. It makes sure that if the same key is registered
multiple times, it has the same type each time. It further processes
the information to determine the database tables needed to implement
the collection, and the SQL statements needed to create, and drop those
tables. It also has the ability to compare its current state to a
Class::AutoDB::CollectionDiff object and generate the SQL statements
needed to alter the current schema the new one.

This class I<does not talk to the database>.

=head1 BUGS and WISH-LIST

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Collection.html#bugs_and_wishlist> 

Wish-list

=head1 METHODS and FUNCTIONS

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Collection.html#methods_and_functions> 
 
=cut

