package Class::AutoDB::Connect;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use DBI;
use Class::AutoClass;
use Class::AutoClass::Args;
use Class::AutoDB::Serialize;
@ISA = qw(Class::AutoClass);

# Mixin for Class::AutoDB. Handles database connection
@AUTO_ATTRIBUTES=qw(dsn dbh dbd database host sock user password 
		    _needs_disconnect);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=(server=>'host', pass=>'password');
%DEFAULTS=(user=>$ENV{USER});
Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  $self->_connect;
}
sub connect {
  my($self,@args)=@_;
  my $args=new Class::AutoClass::Args(@args);
  $self->Class::AutoClass::set_attributes([qw(dbh dsn dbd host server user password)],$args);
  $self->_connect;
}
sub _connect {
  my($self)=@_;
  return $self->dbh if $self->dbh;              # if dbh set, then already connected
  my $dbd=lc($self->dbd)||'mysql';
  $self->throw("-dbd must be 'mysql' at present") if $dbd && $dbd ne 'mysql';
  my $dsn=$self->dsn;
  if ($dsn) {                   # parse off the dbd, database, host elements
    $dsn = "DBI:$dsn" unless $dsn=~ /^dbi/i;
  } else {
    my $database=$self->database;
    return undef unless $database;
    my $host=$self->host || 'localhost';
    my $sock=$self->sock;
    $dsn="DBI:$dbd:database=$database;host=$host".($sock? ";mysql_socket=$sock": undef);
  }
  # Try to establish connection with data source.
  my $dbh = DBI->connect($dsn,$self->user,$self->password,
                         {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, Warn=>0,});
  $self->throw("DBI::connect failed for dsn=$dsn, user=".$self->user.": ".DBI->errstr) unless $dbh;
  if (defined $DB::IN) {        # running in debugger, so set long timeout
    $dbh->do('set session wait_timeout=3600');
  }
  $self->dsn($dsn);
  $self->dbh($dbh);
  $self->_needs_disconnect(1);
  Class::AutoDB::Serialize->dbh($dbh); # TODO: this will change when Serialize changes
  return $dbh;
}
sub is_connected {$_[0]->dbh;}

1;
