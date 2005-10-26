package Class::AutoDB::Table;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Globals;
use Text::Abbrev;
@ISA = qw(Class::AutoClass); # AutoClass must be first!!

@AUTO_ATTRIBUTES=qw(name _keys index);
@OTHER_ATTRIBUTES=qw(keys);
%DEFAULTS=(_keys=>{});
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
my @WHATS=qw(create drop alter);
my %WHATS=abbrev @WHATS;
# TODO: this is re-used in Database.pm.  find a single place for this.
my %TYPES=(string  =>'longtext',
	   integer =>'int',
	   float   =>'double',
	   object  =>'bigint unsigned',);
my @TYPES=keys %TYPES;
my %TYPES_ABBREV=abbrev @TYPES;

my $GLOBALS=Class::AutoDB::Globals->instance();
sub autodb {
  my $self=shift;
  $GLOBALS->autodb(@_);
}
sub dbh {$_[0]->autodb->dbh;}

sub schema {
  my($self,$what)=@_;
  $what or $what='create';
  $what=$WHATS{lc($what)} || $self->throw("Invalid \$what for schema: $what. Should be one of: @WHATS");
  return $self->create if $what eq 'create';
  return $self->drop if $what eq 'drop';
  return $self->alter if $what eq 'alter';
}
# sub create -- implemented in subclasses
# sub alter -- implemented in subclasses
sub drop {
  my($self)=@_;
  my $name=$self->name;
  my $sql="drop table if exists $name";
  wantarray? ($sql): [$sql];
}

1;

__END__

=head1 NAME

Class::AutoDB::Table - Schema information for one table

=head1 SYNOPSIS

This is a helper class for Class::AutoDB::Registry which represents the
schema information for one table.

 use Class::AutoDB::Table;
 my $table=new Class::AutoDB::Table
   (-name=>'Person',
    -keys{name=>'string',dob=>'integer',grade_avg=>'float',friend=>'object'});
 my $name=$table->name; 
 my $keys=$table->keys;           # hash of key=>type pairs
 my @sql=$table->schema;          # SQL statements to create table
 my @sql=$table->schema('create');# same as above
 my @sql=$table->schema('drop');  # SQL statements to drop table
 my @sql=$table->schema('alter'); # SQL statements to add columns 
                                  #   of this table to another

=head1 DESCRIPTION

This class represents schema information for one table. This class is
fed a HASH of key=E<gt>type pairs. Each turns into one column of the
table. In addition, the table has an 'object' column which is a foreign
key pointing to the AutoDB object table and which is the primary key
here. Indexes are defined on all keys (unless index=>0 is passed as an AutoDB 
constructor argument). This class just creates SQL; 
I<it does not talk to the database>.

At present, only our special data types ('string', 'integer', 'float',
'object') are supported. These can be abbreviated. These are translated
into MySQL types as follows:

 ----------------------------------
 | AutoDB type    | MySQL type    |
 ----------------------------------
 |  string        |  longtext     |
 |  integer       |  int          |
 |  float         |  double       |
 |  object        |  bigint       |
 |                | (unsigned)    |
 ----------------------------------

=head1 BUGS and WISH-LIST

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Table.html#bugs_and_wishlist>

=head1 METHODS and FUNCTIONS - Initialization

see  L<http://search.cpan.org/~ccavnor/Class-AutoDB-0.091/docs/Table.html#methods_and_functions>



=cut

