package Class::AutoDB::Table;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Text::Abbrev;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!


  @AUTO_ATTRIBUTES=qw(name 
		      _keys);
  @OTHER_ATTRIBUTES=qw(keys);
  %SYNONYMS=();
  Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}
sub keys {
  my $self=shift;
  my $result= @_? $self->_keys($_[0]): $self->_keys;
  wantarray? %$result: $result;
}
my @CODES=qw(create drop alter);
my %CODES=abbrev @CODES;
my %TYPES=(string  =>'longtext',
	   integer =>'int',
	   float   =>'double',
	   object  =>'varchar(15)', # must match Registry's object type
	   mixed   => 'longtext',);
my @TYPES=CORE::keys %TYPES;
my %TYPES_ABBREV=abbrev @TYPES;

sub schema {
  my($self,$code)=@_;
  $code or $code='create';
  $code=$CODES{lc($code)} || $self->throw("Invalid \$code for schema: $code. Should be one of: @CODES");
  my $sql;
  my $name=$self->name;
  my $keys=$self->keys;
  $code eq 'create' and do {
    my (@columns,$inner_type);
    while(my($key,$type)=each %$keys) {
    	($inner_type)=$type=~/^list\s*\(\s*(.*?)\s*\)/;
    	$type = $inner_type || $type; # get list inner type for verification
      my $sql_type=$TYPES{$TYPES_ABBREV{$type}} or
	      $self->throw("Invalid data type for key $key: $type. Should be one of: ".join(' ',@TYPES));
      push(@columns,"$key $sql_type");
    }
    # make sure that the object column size >= that of the id in the Registry
    unshift @columns, $inner_type?
      ('object varchar(15) not null') :
      ('object varchar(15) not null, primary key (object)');
    $sql=@columns? "create table $name \(".join(',',@columns)."\)": '';
  };
  $code eq 'drop' and do {
    $sql="drop table if exists $name";
  };
  $code eq 'alter' and do {
    my @columns;
    while(my($key,$type)=each %$keys) {
      my $sql_type=$TYPES{$TYPES_ABBREV{$type}} or
	      $self->throw("Invalid data type for key $key: $type. Should be one of: ".join(' ',@TYPES));
      push(@columns,"add $key $sql_type");
    }
    $sql=@columns? "alter table $name ".join(',',@columns): '';
  };
  wantarray? ($sql): [$sql];
}

1;


__END__

# POD documentation - main docs before the code

=head1 NAME

Class::AutoDB::Table - schema information for one table

=head1 SYNOPSIS

This is a helper class for Class::AutoDB::Registration which
represents the schema information for one table

  use Class::AutoDB::Table;
  my $table=new Class::AutoDB::Table(
               -name=>'Person',
               -keys=>{name=>string,sex=>string});
  my $name=$table->name; 
  my $keys=$table->keys;	       # returns hash of key=>type pairs
  my @sql=$table->schema;              # list of SQL statements needed to create table
  my @sql=$table->schema('create');    # same as above
  my @sql=$table->schema('drop');      # list of SQL statements needed to drop table
  my @sql=$table->schema('alter',$other); # list of SQL statements needed to alter
                                       # table to reflect changes in other

=head1 DESCRIPTION

This class represents schema information for one table.  This class is
fed a HASH of key=>type pairs.  Each turns into one column of the
table.  In addition, the table has an 'object' column which is a
foreign key pointing to the AutoDB object table and which is the
primary key here.

NB: At present, only our special data types ('string', 'integer',
'float', 'object') are supported. These can be abbreviated. These are
translated into mySQL types as follows:

  string  => longtext
  integer => int
  float   => double
  object  => int

Indexes are defined on all keys (not yet implemented).

TBD: does this class talk to the database or just generate SQL?

=head1 KNOWN BUGS AND CAVEATS

This is still a work in progress.  

=head2 Bugs, Caveats, and ToDos

  TBD

=head1 AUTHOR - Nat Goodman, Chris Cavnor

Email natg@shore.net

=head1 COPYRIGHT

Copyright (c) 2003 Institute for Systems Biology (ISB). All Rights Reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 APPENDIX

The rest of the documentation describes the methods.

=head2 Constructors

 Title   : new

 Usage   : $table=new Class::AutoDB::Table(
               -name=>'Person',
               -keys=>{name=>string,sex=>string});
 Function: Create object
 Returns : New Class::AutoDB::Table object
 Args    : -name	name of table being registered
           -keys	key=>type pairs. Each becomes a column of table

=head2 Simple attributes

These are methods for getting and setting the values of simple
attributes.  Some of these should be read-only (more precisely, should
only be written by code internal to the object), but this is not
enforced. 

Methods have the same name as the attribute.  To get the value of
attribute xxx, just say $xxx=$object->xxx; To set it, say
$object->xxx($new_value); To clear it, say $object->xxx(undef);

 Attr    : name 
 Function: name of table that registered 
 Access  : read-only

=head2 keys

 Title   : keys
 Usage   : %keys=$table->keys
           -- OR --
           $keys=$table->keys
 Function: Returns key=>type pairs for keys registered for this table
 Args    : None
 Returns : hash or HASH ref of key=>type pairs

=head2 schema

 Title   : schema
 Usage   : @sql=$table->schema
           -- OR --
           @sql=$table->schema($code)
           -- OR --
          $sql=$table->schema
           -- OR --
           $sql=$table->schema($code)
 Function: Returns SQL statements needed to create, drop, or alter the table
 Args    : code		indicates what schema operation is desired
           		'create' -- default
           		'drop'
           		'alter' -- only support adding columns
 Returns : array or ARRAY ref of SQL statements (as strings)

The 'alter' function is a bit of a hack: it generates SQL to add all
columns of the the table to an empty table of the same name. This is
what's needed by the Collection::merge code.  The alternative of doing
it right: comparing two tables and producing SQL to tranform one into
the other is overkill for what we need now.

=cut
