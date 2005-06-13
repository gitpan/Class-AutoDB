package Class::AutoDB::Database;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use DBI;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Registry;
use Class::AutoDB::Cursor;
use Text::Abbrev;
@ISA = qw(Class::AutoClass);

# Mixin for Class::AutoDB. Handles database operations

@AUTO_ATTRIBUTES=qw(object_table
		   _exists);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%DEFAULTS=(object_table=>'_AutoDB');
Class::AutoClass::declare(__PACKAGE__);

# TODO: this is copied from Table.pm.  find a single place for this.
my %TYPES=(string  =>'longtext',
	   integer =>'int',
	   float   =>'double',
	   object  =>'bigint unsigned',);
my @TYPES=keys %TYPES;
my %TYPES_ABBREV=abbrev @TYPES;

# TODO: deal with free-form queries
sub find {
  my $self=shift;
  my $query=$self->parse_query(@_);
  my $cursor=new Class::AutoDB::Cursor(-query=>$query,-dbh=>$self->dbh);
  $cursor;
}
sub get {
  my $self=shift;
  my $cursor=$self->find(@_);
  $cursor->get;
}
sub count {
  my $self=shift;
  my $query=$self->parse_query(@_);
  my $cursor=new Class::AutoDB::Cursor(-query=>$query,-dbh=>$self->dbh);
  $cursor->count;
}
sub parse_query {
  my $self=shift;
  my $args=new Class::AutoClass::Args(@_);
  my $name=$args->collection;
  delete $args->{collection};	# so 'collection' will not be confused with a search key!
  my $query=$args->query? $args->query: $args;

  my $dbh=$self->dbh;
  my $object_table=$self->object_table;
  my $collection=$self->registry->collection($name) || $self->throw("Unknown collection $name");
  my $keys=$collection->keys;
  my @where;
  my %tables=($name=>$name);	# always include base table
  while(my($key,$value)=each %$query) {	# create SQL condition for each search key
    my $type=$keys->{$key} || $self->throw("Unkown key $key for collection $name");
    my($db_type,$list_type,$table);
    if ($type=~/^list/) {
      ($list_type)=$type=~/^list\s*\(\s*(.*)\s*\)/;
      $db_type=$TYPES{$list_type};
      $table=$name."_$key";	# list keys are stored in separate tables
      $tables{$table}=$table;
    } else {
      $db_type=$TYPES{$type};
      $table=$name;		# scalar keys are stored in base table
    }
    if (($type eq 'object' || $type eq 'list(object)') && defined $value) {
      $value=$value->oid;
    }
    $value=$dbh->quote($value,$db_type);
    push(@where,"$table.$key=$value");
  }
  for my $table (keys %tables) { # create join conditions for each table
    push(@where,"$table.oid=$object_table.oid");
  }
  my $from=join(',',$object_table,keys %tables);
  my $where=join(' AND ',@where);
  my $query="FROM $from WHERE $where";
  $query;
}
sub create {
  my($self)=@_;
  $self->throw("Cannot create database unless connected") unless $self->is_connected;
  my $registry=$self->registry;
  my $dbh=$self->dbh;
  my @sql;
  my $object_table=$self->object_table;
  # drop & recreate object table
  push(@sql,(qq(drop table if exists $object_table),
	     qq(create table $object_table (oid bigint unsigned not null,
					    object longblob,
					    primary key (oid)))));
  push(@sql,$registry->schema('create')); # create collections (drops tables first)
  $self->do_sql(@sql);		          # do it!
  $registry->saved($registry->current);	  # current version is now the real one
  $registry->put;		          # store registry
  $self->_exists(1);
}
sub drop {
  my($self)=@_;
  $self->throw("Cannot drop database unless connected") unless $self->is_connected;
  my $registry=$self->registry;
  my $object_table=$self->object_table;
  my @sql;
  push(@sql,$registry->schema('drop'));	  # drop collections
  # drop & recreate object table
  push(@sql,(qq(drop table if exists $object_table),
	     qq(create table $object_table (oid bigint unsigned not null,
					    object longblob,
					    primary key (oid)))));
  $self->do_sql(@sql);		
  my $registry=new Class::AutoDB::Registry; # reset registry
  $self->registry($registry);
  $registry->autodb($self);	# set autodb here so Registry::new won't attempt 'get'
  $registry->put;		# store registry
  $self->_exists(1);
}
sub alter {
  my($self)=@_;
  $self->throw("Cannot alter database unless connected") unless $self->is_connected;
  my $registry=$self->registry;
  my $object_table=$self->object_table;
  my @sql;
  push(@sql,$registry->schema('alter'));  # alter collections
  push(@sql,			          # create object table if necessary
       qq(create table if not exists $object_table (oid bigint unsigned not null,
						    object longblob,
						    primary key (oid))));
  $self->do_sql(@sql);
  $registry->put;		          # store registry
  $self->_exists(1);
}
sub exists {
  my $self=shift;
  return $self->_exists if defined $self->_exists;
  return undef unless $self->is_connected;
  my $dbh=$self->dbh;
  my $object_table=$self->object_table;
  my $tables=$dbh->selectall_arrayref(qq(show tables));
  my $exists=grep {$object_table eq $_->[0]} @$tables;
  $self->_exists($exists||0);
}
sub do_sql {
  my $self=shift;
  my @sql=_flatten(@_);
  $self->throw("Cannot run SQL unless connected") unless $self->is_connected;
  my $dbh=$self->dbh;
  for my $sql (@sql) {
    next unless $sql;
    $dbh->do($sql);
    $self->throw("SQL error: ".$dbh->errstr) if $dbh->err;
  }
}
sub _flatten {map {'ARRAY' eq ref $_? @$_: $_} @_;}

1;
