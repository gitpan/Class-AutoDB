package Class::AutoDB::ListTable;

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Class::AutoClass;
use Text::Abbrev;
use Class::AutoDB::Table;
@ISA = qw(Class::AutoDB::Table);

@AUTO_ATTRIBUTES=qw();
@OTHER_ATTRIBUTES=qw();
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}
# TODO: this is re-used in Database.pm.  find a single place for this.
# TODO: this is re-used in Table.pm.  Reimplement as method
my %TYPES=(string  =>'longtext',
	   integer =>'int',
	   float   =>'double',
	   object  =>'bigint unsigned',);
my @TYPES=keys %TYPES;
my %TYPES_ABBREV=abbrev @TYPES;

my $ROWS_PER_INSERT=10;	# DBMS limit on number of rows that can be inserted per SQL statement
                        # just a guess! can probably be much higher!

sub put {
  my($self,$oid,$key_values)=@_;
  my %keys=$self->keys;
  my $dbh=$self->dbh;
  my $name=$self->name;

  # since there are muliple values per oid, have to delete the old, then insert the new
  my @sql=("delete from $name where oid=$oid");

  my($key)=keys %keys;		# ListTables have just one key
  my $type=$keys{$key};
  my $values=$key_values->{$key}; # should be ARRAY ref
  if ($values && @$values) {
    my @columns=('oid',$key);
    my $columns='('.join(',',@columns).')';
    my $db_type=$TYPES{$type};
    my $row_count=0;
    my @values=@$values;	# do it this way so shift won't munge input
    while(@values) {
      my @vals;
      for (my $i=0; $i<$ROWS_PER_INSERT && @values; $i++) {
	my $value=$dbh->quote(shift @values,$db_type);
	my $row="($oid,$value)";
	push(@vals,$row);
      }
      my $values='values'. join(',',@vals);
      push(@sql,"insert $name $columns $values");
    }
  }
  wantarray? @sql: \@sql;
}
sub create {
  my($self)=@_;
  my $name=$self->name;
  my $keys=$self->keys;
  my @columns=('oid bigint unsigned not null, index(oid)');
  while(my($key,$type)=each %$keys) { # Note: there should be exactly one key
    my $sql_type=$TYPES{$TYPES_ABBREV{$type}} or
      $self->throw("Invalid data type for key $key: $type. Should be one of: ".join(' ',@TYPES));
    my $index=$sql_type ne 'longtext'? "index($key)": "index($key(255))";
    push(@columns,"$key $sql_type,$index");
  }
  my $sql=@columns? "create table $name \(".join(',',@columns)."\)": '';
  wantarray? ($sql): [$sql];
}
sub alter {
  my($self)=@_;
  my $name=$self->name;
  $self->throw("Attempt to alter ListTable $name: ListTable cannot be altered");
}
1;
